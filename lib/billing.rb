module Billing
  require_relative 'billing/instances'
  require_relative 'billing/volumes'

  def self.sync!
    ActiveRecord::Base.transaction do
      from = Billing::Sync.last.started_at
      to   = Time.now
      sync = Billing::Sync.create started_at: Time.now
      Billing::Instances.sync!(from, to, sync)
      Billing::Volumes.sync!(from, to, sync)
      Billing::FloatingIps.sync!(from, to, sync)
      Billing::IpQuotas.sync!(sync)
      Billing::ExternalGateways.sync!(from, to, sync)
      Billing::Images.sync!(from, to, sync)
      Billing::StorageObjects.sync!(sync)
      sync.update_attributes(completed_at: Time.now)
      #raise ActiveRecord::Rollback
    end
  end

  def self.fetch_samples(tenant_id, measurement, from, to)
    timestamp_format = "%Y-%m-%dT%H:%M:%S"
    options = [{'field' => 'timestamp', 'op' => 'ge', 'value' => from.utc.strftime(timestamp_format)},
               {'field' => 'timestamp', 'op' => 'lt', 'value' => to.utc.strftime(timestamp_format)},
               {'field' => 'project_id', 'value' => tenant_id, 'op' => 'eq'}]
    tenant_samples = Fog::Metering.new(OPENSTACK_ARGS).get_samples(measurement, options).body
    tenant_samples.group_by{|s| s['resource_id']}
  end

  def self.billing_run!(year, month)
    unless (1..12).to_a.include?(month) && year.to_i.to_s.length == 4
      raise ArgumentError, "Please supply a valid year and month"
    end

    ActiveRecord::Base.transaction do
      Organization.all.each do |organization|
        # Skip if there's already an invoice for this year/month/org
        next if Billing::Invoice.where(organization: organization, year: year, month: month).any?
        
        invoice = Billing::Invoice.new(organization: organization, year: year, month: month)
        ud = UsageDecorator.new(organization).usage_data(from_date: invoice.period_start, to_date: invoice.period_end)
        invoice.update_attributes(sub_total: ud.sub_total, grand_total: ud.grand_total,
                                  discount:  ud.discount_percent, tax_percent: ud.tax_percent)
      end
    end
  end
end