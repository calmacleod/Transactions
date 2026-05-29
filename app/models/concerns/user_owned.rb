module UserOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :user, optional: true
    before_validation :assign_current_user, on: :create

    scope :for_user, ->(user) { where(user:) }
  end

  private

  def assign_current_user
    self.user ||= Current.user if Current.user.present?
  end
end
