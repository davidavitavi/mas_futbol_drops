require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  FakeSession = Struct.new(:url)

  # Swaps Stripe's API call for a fake for the length of the block, so tests
  # never hit the network. Yields a lambda that returns what was sent to Stripe.
  def with_fake_stripe(url: "https://checkout.stripe.com/c/pay/fake")
    original = Stripe::Checkout::Session.method(:create)
    sent = nil
    Stripe::Checkout::Session.define_singleton_method(:create) do |params = {}, _opts = {}|
      sent = params
      FakeSession.new(url)
    end
    yield -> { sent }
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original)
  end

  test "redirects to Stripe with the jersey's details" do
    jersey = jerseys(:brazil_home)

    with_fake_stripe do |sent|
      post jersey_checkout_url(jersey)

      assert_redirected_to "https://checkout.stripe.com/c/pay/fake"
      assert_response :see_other

      line_item = sent.call[:line_items].first
      assert_equal 8500, line_item[:price_data][:unit_amount]
      assert_equal "Brazil Home 1998", line_item[:price_data][:product_data][:name]
      assert_equal jersey_url(jersey), sent.call[:cancel_url]
    end
  end
end
