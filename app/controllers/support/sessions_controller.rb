class Support::SessionsController < ApplicationController

  layout 'login'
  
  def new
    respond_to do |wants|
      wants.html
    end
  end
  
  def create
    @user = User.find_by_email(params[:user][:email])
    if @user and params[:user][:password].present? and @user.authenticate(params[:user][:password])
      session[:user_id] = @user.id
      redirect_to support_root_path
    else
      flash.now.alert = "Invalid credentials. Please try again."
      render :new
    end
  end
end