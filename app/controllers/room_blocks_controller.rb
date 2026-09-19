class RoomBlocksController < ApplicationController
  before_action :require_clinic_staff
  before_action :set_room, only: :create
  before_action :set_block, only: :destroy

  def index
    @blocks = RoomBlock.includes(:room).order(starts_at: :desc)
    unless params[:past] == "1"
      @blocks = @blocks.where("starts_at >= ? OR COALESCE(array_length(weekdays, 1), 0) > 0", Time.current.beginning_of_day)
    end
    @block = RoomBlock.new(starts_at: Date.current.beginning_of_day, ends_at: Date.current.end_of_day)
    @rooms = Room.order(:name)
    @blocks = paginate(@blocks, per: 20)
  end

  def create
    @block = RoomBlock.new(block_params)
    @block.room = @room if @room
    if @block.save
      redirect_back fallback_location: block_redirect, notice: "Room blocked for the selected period."
    else
      redirect_back fallback_location: block_redirect, alert: @block.errors.full_messages.to_sentence
    end
  end

  def destroy
    @block.destroy
    redirect_back fallback_location: room_blocks_path, notice: "Block removed."
  end

  private

  def set_room
    @room = Room.find(params[:room_id]) if params[:room_id].present?
  end

  def set_block
    @block = RoomBlock.find(params[:id])
  end

  def block_params
    params.require(:room_block).permit(:room_id, :starts_at, :ends_at, :reason, weekdays: [])
  end

  def block_redirect
    @room ? @room : room_blocks_path
  end
end
