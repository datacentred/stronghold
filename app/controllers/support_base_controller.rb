class SupportBaseController < ApplicationController

  before_filter :current_user, :authenticate_user!

  check_authorization

  def current_ability
    @current_ability ||= User::Ability.new(current_user)
  end

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to support_root_url, :alert => exception.message
  end

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def authenticate_user!
    unless current_user
      redirect_to sign_in_path
    end
  end
end