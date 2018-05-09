class UsersController < ApplicationController
  
  # GET /signup
  def new
    @user = User.new
  end

  # POST /signup
  def create
    user = User.new(user_params)
    if user.save
      login(user)
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end