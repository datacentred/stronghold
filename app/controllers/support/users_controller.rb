class Support::UsersController < SupportBaseController

  skip_authorization_check
  authorize_resource class_name: 'User', only: [:destroy]

  def index
    @user = current_user
    render template: 'support/users/profile'
  end

  def update
    if current_user.update(update_params)
      respond_to do |format|
        format.js {
          reauthenticate(update_params[:password]) if update_params[:password].present?
          render :template => "shared/dialog_success", :locals => {message: 'Changes saved', object: current_user }
        }
      end
    else
      respond_to do |format|
        format.js { render :template => "shared/dialog_errors", :locals => {:object => current_user }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user = User.find params[:id]
    ajax_response(@user, :destroy, support_roles_path)
  end

  private

  def update_params
    params.require(:user).permit(:first_name, :last_name,
                                 :password)
  end

end