class Jersey < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged
    belongs_to :category, optional: true

  validates :title, presence: true

  def slug_candidates
    [
      :title,
      [ :title, :season ],
      [ :title, :club, :season ]
    ]
  end

  def should_generate_new_friendly_id?
    slug.blank? || title_changed?
  end
end
