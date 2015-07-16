class Admin::QuotasController < AdminBaseController

  before_filter :find_organization

  def index
    @organizations = Organization.active
  end

  def edit ; end

  def update
    project = Tenant.find(params[:id])
    begin
      OpenStack::Tenant.set_custom_quotas project.uuid, StartingQuota['standard'].deep_merge(quota_params)
      project.organization.update_attributes(limited_storage: update_params[:storage] ? true : false)
      Rails.cache.delete("quotas_for_#{project.uuid}")
      render json: {success: true, message: ''}
    rescue ArgumentError => e
      respond_to do |format|
        format.js { render :template => "shared/dialog_errors", :locals => {:object => OpenStruct.new(full_messages: [e.message], errors: {'quota' => e.message}) } }
      end
    end
  end

  def mail
    Mailer.quota_changed(@organization).deliver_later
    redirect_to edit_admin_quota_path(@organization), notice: "Email delivered."
  end

  private

  def find_organization
    @organization ||= Organization.find(params[:id]) if params[:id]
  end

  def update_params
    params.require(:quota).permit(:compute => [:instances, :cores, :ram],
      :volume => [:volumes, :snapshots, :gigabytes],
      :network => [:floatingip, :router],
      :storage => [:limited_storage])
  end

  def quota_params
    ['compute', 'network', 'volume'].inject({}) do |acc, key|
      acc[key] = Hash[update_params[key].collect { |k, v| [k, v.to_i]}]
      acc
    end
  end

end
