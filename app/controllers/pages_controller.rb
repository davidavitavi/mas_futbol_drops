class PagesController < ApplicationController
  def home
    @jerseys = Jersey.includes(:category).order(created_at: :desc).limit(6)
  end

  def about
  end
end
