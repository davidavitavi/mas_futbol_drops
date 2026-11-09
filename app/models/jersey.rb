class Jersey < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  MAX_PHOTOS = 8
  MAX_PHOTO_SIZE = 10.megabytes
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :category, optional: true

  # Photos are shown in upload order; the first one is the cover, like on Depop.
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 320, 320 ], format: :webp
    attachable.variant :card,  resize_to_fill: [ 800, 600 ], format: :webp
    attachable.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
  end

  validates :title, presence: true
  validate :photos_are_valid

  def cover_photo
    photos.first
  end

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

  private

  def photos_are_valid
    return unless photos.attached?

    if photos.size > MAX_PHOTOS
      errors.add(:photos, "can't be more than #{MAX_PHOTOS}")
    end

    photos.each do |photo|
      unless PHOTO_TYPES.include?(photo.blob.content_type)
        errors.add(:photos, "must be JPG, PNG or WEBP (#{photo.blob.filename} isn't)")
      end

      if photo.blob.byte_size > MAX_PHOTO_SIZE
        errors.add(:photos, "must each be under 10 MB (#{photo.blob.filename} is too big)")
      end
    end
  end
end
