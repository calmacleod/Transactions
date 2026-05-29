class UserInvitation < ApplicationRecord
  CODE_LENGTH = 10
  EXPIRATION = 14.days

  attr_accessor :raw_code

  belongs_to :invited_by, class_name: "User", foreign_key: :invited_by_user_id, optional: true
  belongs_to :accepted_by, class_name: "User", foreign_key: :accepted_by_user_id, optional: true

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :code_digest, :expires_at, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(accepted_at: nil).where(expires_at: Time.current..) }

  def self.create_for!(email_address:, invited_by:)
    code = SecureRandom.alphanumeric(CODE_LENGTH).upcase

    create!(
      email_address:,
      invited_by:,
      code_digest: BCrypt::Password.create(code),
      expires_at: EXPIRATION.from_now
    ).tap { |invitation| invitation.raw_code = code }
  end

  def pending?
    accepted_at.blank? && expires_at.future?
  end

  def valid_code?(code)
    return false unless pending? && code.present?

    BCrypt::Password.new(code_digest).is_password?(code.to_s.strip.upcase)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def accept!(user)
    update!(accepted_by: user, accepted_at: Time.current)
  end
end
