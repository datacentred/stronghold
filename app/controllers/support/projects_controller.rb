class Support::ProjectsController < SupportBaseController
  include UserTenantRoleHelper

  skip_authorization_check

  before_filter :check_power_user_and_cloud
  before_filter :fetch_tenant, only: [:update, :destroy]

  def index
    @tenants = Tenant.where(organization: current_user.organization).includes(:users)
  end

  def create
    @tenant = current_user.organization.tenants.create(name: tenant_params[:name])
    if @tenant.save
      @tenant.update(user_tenant_roles_attributes)
      @tenant.enable!
      javascript_redirect_to support_projects_path
    else
      respond_to do |format|
        format.js { render :template => "shared/dialog_errors", :locals => {:object => @tenant } }
      end
    end
  end

  def update
    if @tenant.update(user_tenant_roles_attributes.merge(name: tenant_params[:name]))
      javascript_redirect_to support_projects_path
    else
      respond_to do |format|
        format.js { render :template => "shared/dialog_errors", :locals => {:object => @tenant } }
      end
    end
  end

  def destroy
    if @tenant.destroy_unless_primary
      redirect_to support_projects_path
    else
      redirect_to support_projects_path, alert: "Couldn't delete project"
    end
  end

  private

  def fetch_tenant
    @tenant ||= Tenant.find(params[:id])
  end

  def check_power_user_and_cloud
    raise ActionController::RoutingError.new('Not Found') unless current_user.power_user? && current_user.organization.cloud?
  end

  def tenant_params
    params.require(:tenant).permit(:name, :users => Hash[current_user.organization.users.map{|u| [u.id.to_s, true]}])
  end

end