class CheckoutsController < ApplicationController
  def create
    jersey = Jersey.friendly.find(params[:jersey_id])

    checkout_session = Stripe::Checkout::Session.create(
      mode: "payment",
      metadata: { jersey_id: jersey.id },
      line_items: [ {
        quantity: 1,
        price_data: {
          currency: "usd",
          unit_amount: (jersey.price * 100).round.to_i,
          product_data: {
            name: jersey.title,
            description: [ jersey.club, jersey.season, ("Size #{jersey.size}" if jersey.size.present?) ].compact_blank.join(" · ")
          }
        }
      } ],
      success_url: checkout_success_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: jersey_url(jersey)
    )

    redirect_to checkout_session.url, allow_other_host: true, status: :see_other
  end

  def success
    return if params[:session_id].blank?

    @checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])
  rescue Stripe::InvalidRequestError
    @checkout_session = nil
  end
end
