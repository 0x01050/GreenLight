class MainController < ApplicationController

  #before_action :redirect_to_room

  # GET /
  def index
    @user = User.new
  end

  private

  def redirect_to_room
    # If the user is logged in already, move them along to their room.
    redirect_to room_path(current_user.room.uid) if current_user
  end
end
