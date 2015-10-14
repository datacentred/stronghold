class SignupsController < ApplicationController

  layout :set_layout

  before_filter :check_enabled, only: [:new, :create]
  before_filter :find_invite, except: [:new, :create, :thanks]
  skip_before_filter :verify_authenticity_token, :only => [:create]

  def new
    if current_user
      redirect_to support_root_path
    else
      @email = params[:email]
      @customer_signup = CustomerSignup.new
    end
  end

  def create
    extra_headers = { ip_address: request.remote_ip,
                      real_ip: request.headers['X-Real-IP'],
                      forwarded_ip: request.headers['X-Forwarded-For'],
                      accept_language: request.headers['Accept-Language'],
                      user_agent: request.headers['User-Agent'],
                      device_id: device_cookie
                    }
    @customer_signup = CustomerSignup.new(create_params.merge(extra_headers))
    if @customer_signup.save
      respond_to do |format|
        format.html { redirect_to thanks_path }
        format.json { head :ok }
      end
    else
      respond_to do |format|
        format.html {
          flash.now.alert = @customer_signup.errors.full_messages.join('<br>').html_safe
          render :new
        }
        format.json { render json: {errors: @customer_signup.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def thanks
    if current_user
      redirect_to support_root_path 
    else
      render :confirm
    end
  end

  def edit
    reset_session
    @registration = RegistrationGenerator.new(nil,{})  
  end

  def update
    @registration = RegistrationGenerator.new(@invite, update_params)
    if verify_recaptcha(:model => @registration) && @registration.generate!
      Rails.cache.write("up_#{@registration.user.uuid}", update_params[:password], expires_in: 60.minutes)
      session[:user_id] = @registration.user.id
      session[:created_at] = Time.zone.now
      session[:token] = @registration.user.authenticate(update_params[:password])
      redirect_to current_organization.known_to_payment_gateway? ? support_root_path : activate_path
    else
      flash.clear
      flash.now.alert = @registration.errors.full_messages.join('<br>').html_safe
      render :edit    
    end
  end

  private

  def current_ability
    @current_ability ||= User::Ability.new(current_user)
  end

  def set_layout
    case action_name
    when "new", "create", "thanks", "edit", "update"
      "customer-sign-up"
    else
      "application"
    end
  end

  def update_params
    params.permit(:password)
  end

  def find_invite
    @invite = Invite.find_by_token(params[:token])
    raise ActionController::RoutingError.new('Not Found') unless @invite && @invite.can_register?
  end

  def create_params
    params.permit(:organization_name, :email, :discount_code)
  end

  def check_enabled
    unless Stronghold::SIGNUPS_ENABLED
      @wait_list_entry = WaitListEntry.new
      respond_to do |format|
        format.html {
          render :sorry
        }
        format.json {
          render json: {errors: ["Sorry, not currently accepting signups."]}, status: :unprocessable_entity
        }
      end
      return
    end
  end

end