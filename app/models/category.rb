class Category < ApplicationRecord
  include UserOwned

  has_many :expense_transactions, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :user_id }

  scope :by_name, -> { order(:name) }
end
