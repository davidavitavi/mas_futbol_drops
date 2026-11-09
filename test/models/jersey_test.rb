require "test_helper"

class JerseyTest < ActiveSupport::TestCase
  def photo(name = "jersey.jpg", type = "image/jpeg")
    fixture_file_upload(name, type)
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
end
