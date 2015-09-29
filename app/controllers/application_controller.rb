class ApplicationController < ActionController::Base

  before_filter :device_cookie

  def javascript_redirect_to(path)
    render js: "window.location.replace('#{path}')"
  end

  def current_section; end
  helper_method :current_section

  before_action { Authorization.current_user = nil }

  def current_user
    @current_user ||= User.find_by_id(session[:user_id]) if session[:user_id]
    reset_session unless @current_user
    @current_user
  end
  helper_method :current_user

  def device_cookie
    args = {value: SecureRandom.hex, expires: 2.years.from_now}
    cookies[:_d] = args unless cookies[:_d]
    @device_cookie ||= cookies[:_d]
  end
  helper_method :device_cookie

  helper Starburst::AnnouncementsHelper

end
