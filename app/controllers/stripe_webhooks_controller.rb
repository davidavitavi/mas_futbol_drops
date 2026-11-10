# Stripe calls this after a payment. It isn't a browser, so it skips
# the browser check and CSRF token; the signature check proves it's Stripe.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    event = Stripe::Webhook.construct_event(
      request.body.read,
      request.headers["Stripe-Signature"],
      webhook_secret
    )

    if event.type == "checkout.session.completed" && event.data.object.payment_status == "paid"
      jersey_id = event.data.object.metadata["jersey_id"]
      Jersey.find_by(id: jersey_id)&.mark_sold!
    end

    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def webhook_secret
    ENV["STRIPE_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :webhook_secret)
  end
end
