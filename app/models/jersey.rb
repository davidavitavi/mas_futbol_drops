class Jersey < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  MAX_PHOTOS = 8
  MAX_PHOTO_SIZE = 10.megabytes
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  # A crop is the photo's center point (as fractions of its width/height) plus a zoom.
  # zoom 1 fills the square frame; below 1 zooms out to show more; above 1 zooms in.
  DEFAULT_CROP = { "x" => 0.5, "y" => 0.5, "zoom" => 1.0 }.freeze
  ZOOM_RANGE = 0.5..4.0

  belongs_to :category, optional: true

  # Photos are shown in upload order; the first one is the cover, like on Depop.
  # Variants only shrink photos (never crop them), so the saved crop can frame them freely.
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 400, 400 ], format: :webp
    attachable.variant :card,  resize_to_limit: [ 900, 900 ], format: :webp
    attachable.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
    attachable.variant :zoom,  resize_to_limit: [ 2400, 2400 ], format: :webp
  end

  validates :title, presence: true
  validate :photos_are_valid

  scope :available, -> { where(sold_at: nil) }

  def sold?
    sold_at.present?
  end

  # Safe to call twice: a jersey that's already sold keeps its original sale time.
  def mark_sold!
    update!(sold_at: Time.current) unless sold?
  end

  # Where a photo sits inside a square frame, as CSS percentages of the frame.
  # Shared by the views and mirrored in photo_upload_controller.js for the live editor.
  def self.crop_box(width, height, crop)
    aspect = width.to_f / height
    zoom   = crop["zoom"].to_f
    w = [ aspect, 1 ].max * 100 * zoom
    h = [ 1 / aspect, 1 ].max * 100 * zoom

    left = 50 - crop["x"].to_f * w
    top  = 50 - crop["y"].to_f * h

    # A photo bigger than the frame can't be dragged past its edges; a smaller one stays centered.
    left = w >= 100 ? left.clamp(100 - w, 0) : (100 - w) / 2
    top  = h >= 100 ? top.clamp(100 - h, 0) : (100 - h) / 2

    { left: left, top: top, width: w, height: h }
  end

  # "x,y,zoom" from the form -> a safe crop hash, or nil if it's malformed.
  def self.parse_crop(value)
    x, y, zoom = value.to_s.split(",").map { |n| Float(n, exception: false) }
    return nil unless [ x, y, zoom ].all? { |n| n&.finite? }

    { "x" => x.clamp(0.0, 1.0), "y" => y.clamp(0.0, 1.0), "zoom" => zoom.clamp(ZOOM_RANGE.begin, ZOOM_RANGE.end) }
  end

  # Attachments in upload order (unsaved ones last).
  def ordered_photos
    photos.attachments.sort_by { |photo| photo.id || Float::INFINITY }
  end

  def cover_photo
    ordered_photos.first
  end

  def crop_for(photo)
    photo_crops[photo.blob_id.to_s] || DEFAULT_CROP
  end

  # crop_values arrive in the same order as the photos in the form.
  def apply_photo_crops(crop_values)
    crops = {}
    ordered_photos.zip(Array(crop_values)) do |photo, value|
      crop = self.class.parse_crop(value)
      crops[photo.blob_id.to_s] = crop if crop && crop != DEFAULT_CROP
    end
    update_column(:photo_crops, crops)
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
