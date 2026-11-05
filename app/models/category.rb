class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :jerseys, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
