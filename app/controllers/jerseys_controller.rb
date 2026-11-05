class JerseysController < ApplicationController
    before_action :authenticate_user!, except: %i[index show]
  before_action :require_admin!, except: %i[index show]
  before_action :set_jersey, only: %i[ show edit update destroy ]

  # GET /jerseys or /jerseys.json
  def index
    @categories = Category.order(:name)
    @jerseys = Jersey.includes(:category).order(created_at: :desc)

    if params[:category].present?
      @category = Category.friendly.find(params[:category])
      @jerseys = @jerseys.where(category: @category)
    end

    if params[:query].present?
      query = "%#{Jersey.sanitize_sql_like(params[:query])}%"
      @jerseys = @jerseys.where("title ILIKE :q OR club ILIKE :q", q: query)
    end
  end

  # GET /jerseys/new
  def new
    @jersey = Jersey.new
  end

  # GET /jerseys/1/edit
  def edit
  end

  # POST /jerseys or /jerseys.json
  def create
    @jersey = Jersey.new(jersey_params)

    respond_to do |format|
      if @jersey.save
        format.html { redirect_to @jersey, notice: "Jersey was successfully created." }
        format.json { render :show, status: :created, location: @jersey }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @jersey.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /jerseys/1 or /jerseys/1.json
  def update
    respond_to do |format|
      if @jersey.update(jersey_params)
        format.html { redirect_to @jersey, notice: "Jersey was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @jersey }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @jersey.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /jerseys/1 or /jerseys/1.json
  def destroy
    @jersey.destroy!

    respond_to do |format|
      format.html { redirect_to jerseys_path, notice: "Jersey was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_jersey
     @jersey = Jersey.friendly.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def jersey_params
      params.expect(jersey: [ :title, :club, :season, :size, :price, :description, :category_id ])
    end
end
