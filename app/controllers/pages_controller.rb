class PagesController < ApplicationController
  def home
    @jerseys = Jersey.includes(:category).with_attached_photos.order(created_at: :desc).limit(6)
  end

  def about
  end
end
