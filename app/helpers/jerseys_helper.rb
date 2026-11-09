module JerseysHelper
  # An <img> framed by the admin's saved crop. Put it inside a square,
  # `relative overflow-hidden` box. Until Active Storage has measured the photo
  # it falls back to a plain centered fill.
  def cropped_photo_tag(jersey, photo, variant, alt: "", **options)
    image_tag photo.variant(variant), alt: alt, **options.except(:class), **crop_attributes(jersey, photo, options[:class])
  end

  # The inline style for a cropped photo, or nil if it hasn't been measured yet.
  def photo_crop_style(jersey, photo)
    width, height = photo.blob.metadata.values_at("width", "height").map(&:to_i)
    return if width.zero? || height.zero?

    box = Jersey.crop_box(width, height, jersey.crop_for(photo))
    format("left:%.3f%%;top:%.3f%%;width:%.3f%%;height:%.3f%%", box[:left], box[:top], box[:width], box[:height])
  end

  private

  def crop_attributes(jersey, photo, extra_classes)
    if (style = photo_crop_style(jersey, photo))
      { class: [ "absolute max-w-none", extra_classes ], style: style }
    else
      { class: [ "absolute inset-0 h-full w-full object-cover", extra_classes ] }
    end
  end
end
