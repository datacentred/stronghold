class Voucher < ActiveRecord::Base
  has_many :organization_vouchers, -> { uniq }
  has_many :organizations, :through => :organization_vouchers

  before_validation :create_code, on: :create

  validates :name, :description, :code,
            :duration, :discount_percent, :expires_at,
            presence: true, allow_blank: false

  validates :code, uniqueness: true
  validates :duration, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate -> { errors.add(:expires_at, "is in the past") if expired? }

  scope :active,  -> { where('expires_at > ?', Time.now.utc) }
  scope :expired, -> { where('expires_at <= ?', Time.now.utc) }

  def expired?
    expires_at < Time.now.utc
  end

  private

  def create_code
    return if code.present?

    self.code = random_code
  end

  def random_code
    c = (0...8).map { ('a'..'z').to_a[rand(26)] }.join.upcase
    return random_code if Voucher.find_by_code(c)
    c
  end

end
