class RegistrationGenerator
  include ActiveModel::Validations

  attr_reader :invite, :password,
              :organization, :user

  def initialize(invite, params)
    @invite            = invite
    @password          = params[:password]
  end

  def generate!
    if !invite.can_register?
      errors.add :base, I18n.t(:signup_token_not_valid)
    elsif password.length < 8
      errors.add :base,  I18n.t(:password_too_short)
    else
      error = nil
      ActiveRecord::Base.transaction do
        begin
          create_registration
        rescue StandardError => e
          error = e
          raise ActiveRecord::Rollback
        end
      end

      raise error if error
      return true
    end 
    false
  end

  private

  def create_registration
    @organization = invite.organization
    if invite.power_invite?
      @owners = @organization.roles.create name: I18n.t(:owners), power_user: true
    end

    roles = (invite.roles + [@owners]).flatten.compact
    @user = @organization.users.create email: invite.email.downcase, password: password,
                                       roles: roles
    @user.save!
    OpenStack::User.update_enabled(@user.uuid, false) unless @organization.has_payment_method?
    unless Rails.env.test?
      UserTenantRole.required_role_ids.each do |role_uuid|
        UserTenantRole.create(user_id: @user.id, tenant_id: @organization.primary_tenant.id,
                              role_uuid: role_uuid)
      end
    end
    
    Notifications.notify(:new_user, "#{@user.name} added to organization #{@organization.name}.")

    invite.complete!
  end
end