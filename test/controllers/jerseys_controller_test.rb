require "test_helper"

class JerseysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @jersey = jerseys(:brazil_home)
  end

  def jersey_params
    { title: "Argentina Home 1986", club: "Argentina", season: "1986", size: "M", price: 150, description: "Mexico '86.", category_id: categories(:national_teams).id }
  end

  def titles_on_page
    css_select("#jerseys h3").map { |heading| heading.text.strip }
  end

  # --- Anyone can browse ---

  test "should get index" do
    get jerseys_url
    assert_response :success
  end

  test "should show jersey" do
    get jersey_url(@jersey)
    assert_response :success
  end

  test "sorts by price low to high with unpriced jerseys last" do
    get jerseys_url(sort: "price_asc")
    assert_equal [ "Brazil Home 1998", "AC Milan Away 2006", "Italy Training Top" ], titles_on_page
  end

  test "sorts by price high to low with unpriced jerseys still last" do
    get jerseys_url(sort: "price_desc")
    assert_equal [ "AC Milan Away 2006", "Brazil Home 1998", "Italy Training Top" ], titles_on_page
  end

  # --- Admins manage jerseys ---

  test "admin should get new" do
    sign_in users(:admin)
    get new_jersey_url
    assert_response :success
  end

  test "admin should create jersey" do
    sign_in users(:admin)

    assert_difference("Jersey.count") do
      post jerseys_url, params: { jersey: jersey_params }
    end

    assert_redirected_to jersey_url(Jersey.last)
  end

  test "admin should get edit" do
    sign_in users(:admin)
    get edit_jersey_url(@jersey)
    assert_response :success
  end

  test "admin should update jersey" do
    sign_in users(:admin)
    patch jersey_url(@jersey), params: { jersey: { price: 95 } }

    assert_redirected_to jersey_url(@jersey.reload)
    assert_equal 95, @jersey.price
  end

  test "admin should destroy jersey" do
    sign_in users(:admin)

    assert_difference("Jersey.count", -1) do
      delete jersey_url(@jersey)
    end

    assert_redirected_to jerseys_url
  end

  # --- Everyone else is kept out ---

  test "signed-out visitors are sent to sign in" do
    get new_jersey_url
    assert_redirected_to new_user_session_url

    assert_no_difference("Jersey.count") do
      post jerseys_url, params: { jersey: jersey_params }
    end
    assert_redirected_to new_user_session_url
  end

  test "shoppers can't create, edit or delete jerseys" do
    sign_in users(:shopper)

    get new_jersey_url
    assert_redirected_to root_url

    assert_no_difference("Jersey.count") do
      post jerseys_url, params: { jersey: jersey_params }
    end
    assert_redirected_to root_url

    get edit_jersey_url(@jersey)
    assert_redirected_to root_url

    patch jersey_url(@jersey), params: { jersey: { price: 1 } }
    assert_redirected_to root_url
    assert_equal 85, @jersey.reload.price

    assert_no_difference("Jersey.count") do
      delete jersey_url(@jersey)
    end
    assert_redirected_to root_url
  end
end
