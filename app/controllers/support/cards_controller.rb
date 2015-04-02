class Support::CardsController < LocallyAuthorizedController
  
  def index

  end

  def new
    @customer_signup = CustomerSignup.find_by_email(current_user.email)
  end

  def create
    @customer_signup = CustomerSignup.find_by_uuid(create_params[:signup_uuid])
    if @customer_signup.ready?
      current_user.organization.update_attributes(stripe_customer_id: @customer_signup.stripe_customer_id)
      current_user.organization.enable!
      session[:token] = current_user.authenticate(Rails.cache.fetch("up_#{current_user.uuid}"))
      Rails.cache.delete("up_#{current_user.uuid}")
      Announcement.create(title: 'Welcome', body: 'Your card details are verified and you may now begin using cloud services!',
        limit_field: 'id', limit_value: current_user.id)
      redirect_to support_root_path
    else
      render :new
    end
  end

  def edit

  end

  def update

  end

  private

  def create_params
    params.permit(:stripe_token, :signup_uuid)
  end

end