require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  SECRET = "whsec_test_secret"

  setup do
    @jersey = jerseys(:brazil_home)
    ENV["STRIPE_WEBHOOK_SECRET"] = SECRET
  end

  teardown do
    ENV.delete("STRIPE_WEBHOOK_SECRET")
  end

  # Builds the JSON Stripe sends when a checkout finishes.
  def checkout_completed(jersey, payment_status: "paid")
    {
      id: "evt_test",
      object: "event",
      type: "checkout.session.completed",
      data: { object: { id: "cs_test", object: "checkout.session", payment_status: payment_status, metadata: { jersey_id: jersey.id.to_s } } }
    }.to_json
  end

  # Signs the payload the way Stripe does, then posts it to the webhook.
  def send_webhook(payload, secret: SECRET)
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    header = Stripe::Webhook::Signature.generate_header(timestamp, signature)

    post "/webhooks/stripe", params: payload, headers: { "Stripe-Signature" => header, "Content-Type" => "application/json" }
  end

  test "a paid checkout marks the jersey sold" do
    send_webhook checkout_completed(@jersey)

    assert_response :ok
    assert @jersey.reload.sold?
  end

  test "the same webhook arriving twice keeps the first sale time" do
    send_webhook checkout_completed(@jersey)
    first_sale = @jersey.reload.sold_at

    travel 1.hour do
      send_webhook checkout_completed(@jersey)
    end

    assert_response :ok
    assert_equal first_sale, @jersey.reload.sold_at
  end

  test "an unpaid checkout doesn't mark the jersey sold" do
    send_webhook checkout_completed(@jersey, payment_status: "unpaid")

    assert_response :ok
    assert_not @jersey.reload.sold?
  end

  test "a webhook with a bad signature is rejected" do
    send_webhook checkout_completed(@jersey), secret: "whsec_someone_else"

    assert_response :bad_request
    assert_not @jersey.reload.sold?
  end
end