class AsksController < ApplicationController
  before_action :set_ask, only: %i[show edit update destroy]

  def index
    @asks = current_user.asks.includes(:latest_ask_draft).order(created_at: :desc)
  end

  def show
    @ask_drafts = @ask.ask_drafts.order(created_at: :desc)
  end

  def new
    @ask = current_user.asks.build(asking_for: "prayer", vocabulary: "prayer", visibility: "named")
  end

  def create
    @ask = current_user.asks.build(ask_params)
    if @ask.save
      redirect_to @ask
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ask.update(ask_params)
      redirect_to @ask
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ask.destroy
    redirect_to asks_path
  end

  private

  def set_ask
    @ask = current_user.asks.find(params[:id])
  end

  def ask_params
    params.require(:ask).permit(:whats_going_on, :asking_for, :moment_on, :vocabulary, :visibility)
  end
end
