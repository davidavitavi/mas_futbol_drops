class JerseysController < ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  before_action :require_admin!, except: %i[index show]
  before_action :set_jersey, only: %i[show edit update destroy]

  # GET /jerseys
  def index
    @categories = Category.order(:name)
    @jerseys = Jersey.includes(:category).with_attached_photos.order(created_at: :desc)

    if params[:category].present?
      @category = Category.friendly.find(params[:category])
      @jerseys = @jerseys.where(category: @category)
    end

    if params[:query].present?
      query = "%#{Jersey.sanitize_sql_like(params[:query])}%"
      @jerseys = @jerseys.where("title ILIKE :q OR club ILIKE :q", q: query)
    end

    # Jerseys without a price always go last, whichever way you sort.
    price = Jersey.arel_table[:price]
    case params[:sort]
    when "price_asc"  then @jerseys = @jerseys.reorder(price.asc.nulls_last)
    when "price_desc" then @jerseys = @jerseys.reorder(price.desc.nulls_last)
    end
  end

  # GET /jerseys/:id
  def show
    @related = Jersey.includes(:category).with_attached_photos
                     .where(category_id: @jersey.category_id)
                     .where.not(id: @jersey.id)
                     .order(created_at: :desc)
                     .limit(3)
  end

  # GET /jerseys/new
  def new
    @jersey = Jersey.new
  end

  # GET /jerseys/:id/edit
  def edit
  end

  # POST /jerseys
  def create
    @jersey = Jersey.new(jersey_params)

    respond_to do |format|
      if @jersey.save
        @jersey.apply_photo_crops(params[:photo_crops]) if params.key?(:photo_crops)
        format.html { redirect_to @jersey, notice: "Jersey was successfully created." }
        format.json { render :show, status: :created, location: @jersey }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @jersey.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /jerseys/:id
  def update
    respond_to do |format|
      if @jersey.update(jersey_params)
        @jersey.apply_photo_crops(params[:photo_crops]) if params.key?(:photo_crops)
        format.html { redirect_to @jersey, notice: "Jersey was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @jersey }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @jersey.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /jerseys/:id
  def destroy
    @jersey.destroy!

    respond_to do |format|
      format.html { redirect_to jerseys_path, notice: "Jersey was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_jersey
    @jersey = Jersey.friendly.find(params.expect(:id))
  end

  def jersey_params
    params.expect(jersey: [ :title, :club, :season, :size, :price, :description, :category_id, photos: [] ])
  end
end
