class User < ApplicationRecord
  ROLES = %w[regular admin].freeze
  DEFAULT_CATEGORIES = [
    [ "Groceries", "#059669", 800_00 ],
    [ "Restaurants", "#dc2626", 450_00 ],
    [ "Shopping", "#2563eb", 300_00 ],
    [ "Subscriptions", "#9333ea", 250_00 ],
    [ "Pets", "#7c3aed", 200_00 ],
    [ "Entertainment", "#c2410c", 150_00 ],
    [ "Transportation", "#0891b2", 250_00 ],
    [ "Health", "#be185d", 200_00 ],
    [ "Home", "#0f766e", 500_00 ],
    [ "Travel", "#4f46e5", 400_00 ],
    [ "Payments", "#16a34a", nil ],
    [ "Refunds & Credits", "#0d9488", nil ],
    [ "Uncategorized", "#64748b", nil ]
  ].freeze
  DEFAULT_SUBCATEGORIES = [
    [ "Gift", "#db2777" ],
    [ "Work", "#2563eb" ],
    [ "Reimbursable", "#059669" ],
    [ "Household", "#d97706" ],
    [ "Recurring", "#7c3aed" ],
    [ "One-off", "#64748b" ]
  ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :saved_transaction_queries, dependent: :destroy
  has_many :ai_chats, dependent: :destroy
  has_many :ai_chat_messages, dependent: :nullify
  has_many :ai_chat_transactions, dependent: :nullify
  has_many :ai_requests, dependent: :nullify
  has_many :categories, dependent: :destroy
  has_many :classification_runs, dependent: :destroy
  has_many :expense_transactions, dependent: :destroy
  has_many :import_batches, dependent: :destroy
  has_many :insights, dependent: :destroy
  has_many :insight_transactions, dependent: :nullify
  has_many :transaction_subcategories, dependent: :destroy
  has_many :expense_transaction_subcategories, dependent: :nullify
  has_many :sent_invitations, class_name: "UserInvitation", foreign_key: :invited_by_user_id, dependent: :nullify
  has_many :accepted_invitations, class_name: "UserInvitation", foreign_key: :accepted_by_user_id, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :csv_reminder_wday, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 6 }
  validates :csv_reminder_hour, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }
  validate :preferred_ai_model_is_user_selectable

  after_create :seed_default_taxonomies

  scope :csv_reminders_due_at, ->(time) {
    where(csv_reminder_enabled: true, csv_reminder_wday: time.wday, csv_reminder_hour: time.hour)
      .where("csv_reminder_last_sent_at IS NULL OR csv_reminder_last_sent_at < ?", time.beginning_of_day)
  }
  scope :admins, -> { where(role: "admin") }

  def admin?
    role == "admin"
  end

  def regular?
    role == "regular"
  end

  def onboarding_required?
    onboarding_dismissed_at.blank?
  end

  def csv_reminder_due_at?(time)
    csv_reminder_enabled? &&
      csv_reminder_wday == time.wday &&
      csv_reminder_hour == time.hour &&
      (csv_reminder_last_sent_at.blank? || csv_reminder_last_sent_at < time.beginning_of_day)
  end

  def csv_reminder_label
    return "Off" unless csv_reminder_enabled?

    "#{Date::DAYNAMES.fetch(csv_reminder_wday)} at #{Time.zone.local(2000, 1, 1, csv_reminder_hour).strftime('%-l:00 %p')}"
  end

  def effective_ai_model
    return preferred_ai_model if preferred_ai_model.present? && Model.user_selectable.exists?(model_id: preferred_ai_model)

    Ai::Controls.model
  end

  private

  def seed_default_taxonomies
    DEFAULT_CATEGORIES.each do |name, color, monthly_budget_cents|
      categories.find_or_create_by!(name:) do |category|
        category.color = color
        category.monthly_budget_cents = monthly_budget_cents
      end
    end

    DEFAULT_SUBCATEGORIES.each do |name, color|
      transaction_subcategories.find_or_create_by!(name:) do |subcategory|
        subcategory.color = color
      end
    end
  end

  def preferred_ai_model_is_user_selectable
    return if preferred_ai_model.blank?
    return if Model.user_selectable.exists?(model_id: preferred_ai_model)

    errors.add(:preferred_ai_model, "must be available for users")
  end
end
