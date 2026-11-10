require "test_helper"

class JerseyTest < ActiveSupport::TestCase
  def photo(name = "jersey.jpg", type = "image/jpeg")
    { io: file_fixture(name).open, filename: name, content_type: type }
  end

  test "can save several photos at once and the first is the cover" do
    jersey = Jersey.new(title: "Brazil Home 1998")
    jersey.photos.attach([ photo, photo ])

    assert jersey.save
    assert_equal 2, jersey.photos.count
    assert_equal jersey.photos.first, jersey.cover_photo
  end

  test "rejects more than the photo limit" do
    jersey = Jersey.new(title: "Brazil Home 1998")
    jersey.photos.attach(Array.new(Jersey::MAX_PHOTOS + 1) { photo })

    assert_not jersey.valid?
    assert_includes jersey.errors[:photos].join, "can't be more than"
  end

  test "rejects files that aren't images" do
    jersey = Jersey.new(title: "Brazil Home 1998")
    jersey.photos.attach(photo("notes.txt", "text/plain"))

    assert_not jersey.valid?
    assert_includes jersey.errors[:photos].join, "must be JPG, PNG or WEBP"
  end

  test "crop box fills the frame by default and centers the photo" do
    # A portrait 600x800 photo at zoom 1: full width, overflowing top and bottom equally.
    box = Jersey.crop_box(600, 800, Jersey::DEFAULT_CROP)
    assert_in_delta 0, box[:left]
    assert_in_delta 100, box[:width]
    assert_in_delta 133.333, box[:height], 0.01
    assert_in_delta(-16.667, box[:top], 0.01)
  end

  test "crop box can't be dragged past the photo's edges" do
    box = Jersey.crop_box(800, 800, { "x" => 0.0, "y" => 1.0, "zoom" => 2.0 })
    assert_in_delta 0, box[:left]      # pinned to the left edge
    assert_in_delta(-100, box[:top])   # pinned to the bottom edge
  end

  test "zooming out shrinks the photo and keeps it centered" do
    box = Jersey.crop_box(800, 800, { "x" => 0.9, "y" => 0.1, "zoom" => 0.5 })
    assert_in_delta 50, box[:width]
    assert_in_delta 25, box[:left]
    assert_in_delta 25, box[:top]
  end

  test "parse_crop keeps values in range and rejects junk" do
    assert_equal({ "x" => 1.0, "y" => 0.0, "zoom" => 4.0 }, Jersey.parse_crop("1.5,-2,9"))
    assert_nil Jersey.parse_crop("abc")
    assert_nil Jersey.parse_crop("0.5,0.5")
  end

  test "saves a crop for each photo in upload order" do
    jersey = Jersey.new(title: "Brazil Home 1998")
    jersey.photos.attach([ photo, photo ])
    jersey.save!

    jersey.apply_photo_crops([ "0.5,0.5,1", "0.3,0.6,1.8" ])
    first, second = jersey.ordered_photos

    assert_equal Jersey::DEFAULT_CROP, jersey.reload.crop_for(first)
    assert_equal({ "x" => 0.3, "y" => 0.6, "zoom" => 1.8 }, jersey.crop_for(second))
  end

  test "a jersey isn't sold until it's marked sold" do
    jersey = jerseys(:brazil_home)
    assert_not jersey.sold?

    jersey.mark_sold!
    assert jersey.sold?
    assert_not_includes Jersey.available, jersey
  end

  test "marking a jersey sold twice keeps the first sale time" do
    jersey = jerseys(:brazil_home)
    jersey.mark_sold!
    first_sale = jersey.sold_at

    travel 1.hour do
      jersey.mark_sold!
    end

    assert_equal first_sale, jersey.reload.sold_at
  end
end
