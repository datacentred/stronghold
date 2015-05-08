class User < ActiveRecord::Base
  audited only: [:first_name, :last_name, :email]

  attr_accessor :password, :password_confirmation, :token

  authenticates_with_keystone
  syncs_with_keystone as: 'OpenStack::User', actions: [:create, :destroy]
  after_save :update_password
  after_commit :check_openstack_access, on: :create

  after_create :set_local_password, :subscribe_to_status_io
  after_commit :generate_ec2_credentials, on: :create

  has_and_belongs_to_many :roles
  belongs_to :organization
  has_many :user_tenant_roles, dependent: :destroy
  has_many :tenants, :through => :user_tenant_roles

  validates :email, :uniqueness => true
  validates :email, :organization_id, :presence => true
  validates :first_name, :last_name, length: {minimum: 1}, allow_blank: false
  validates :password, :presence => true, :on => :create
  validate :password_complexity

  scope :active, -> { joins(:organization).where("organizations.disabled = ?", false)}

  def staff?
    organization.staff?
  end

  def cloud?
    organization.cloud?
  end

  def admin?
    roles.any?(&:power_user?)
  end

  def as_hash
    { email: email }
  end

  def unique_id
    "stronghold_#{id}"
  end

  def keystone_params
    { email: email, name: email,
      tenant_id: organization.primary_tenant.uuid,
      enabled: organization.has_payment_method? && has_permission?('cloud.read'),
      password: password
    }
  end

  def has_permission?(permission)
    power_user? || roles.collect(&:permissions).flatten.include?(permission)
  end

  def power_user?
    roles.collect(&:power_user?).include? true
  end

  def name
    name = "#{first_name} #{last_name}".strip
    name.blank? ? email : name
  end

  def authenticate(unencrypted_password)
    setup_password_from_openstack(unencrypted_password) if password_digest.nil?
    begin
      authed = BCrypt::Password.new(password_digest) == unencrypted_password && self
    rescue BCrypt::Errors::InvalidHash
      authed = false
    end

    if authed
      token = authenticate_openstack(unencrypted_password)
    end
    token || authed
  end
  
  def setup_password_from_openstack(unencrypted_password)
    if authenticate_openstack(unencrypted_password)
      set_local_password(unencrypted_password)
    end
  end
  
  def set_local_password(p=nil)
    password = p if p
    if password.present?
      cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      update_column(:password_digest, BCrypt::Password.create(password, cost: cost))
    end
  end

  private

  def password_complexity
    if password.present?
      if password.length < 8
        errors.add(:base, I18n.t(:password_too_short))
      elsif !(password =~ /[A-Z]/ && password =~ /[a-z]/)
        errors.add(:base, "Password should contain at least one uppercase and one lowercase letter.")
      elsif !(password =~ /[0-9]/)
        errors.add(:base, "Password should containa at least one number.")
      end
    end
  end

  def update_password
    if password.present?
      OpenStack::User.update_password uuid, password
      set_local_password
    end
  end

  def generate_ec2_credentials
    if Rails.env.production?
      CreateEC2CredentialsJob.perform_later(self)
    end
  end

  def subscribe_to_status_io
    if Rails.env.production?
      StatusIOSubscribeJob.perform_later(email)
    end
  end

  def check_openstack_access
    if Rails.env.production?
      CheckOpenStackAccessJob.perform_later(self)
    end
  end

end