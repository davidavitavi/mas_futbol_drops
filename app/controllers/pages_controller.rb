class PagesController < ApplicationController
  def home
    @jerseys = Jersey.order(created_at: :desc).limit(6)
  end

  def about
  end
end
