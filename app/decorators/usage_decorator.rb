class UsageDecorator < ApplicationDecorator
  include DateTimeHelper

  attr_reader :from_date, :to_date

  def latest_usage_data(from=Time.now.beginning_of_month, to=Time.now, count=0)
    @from_date, @to_date = from, to
    return usage_data(from_date: from, to_date: to) if count > 20
    key = "org#{model.id}_#{from.strftime(timestamp_format)}_#{to.strftime(timestamp_format)}"
    Rails.cache.exist?(key) ? Rails.cache.fetch(key) : latest_usage_data(from, to - 1.hour, count + 1)
  end

  def usage_data(args=nil)
    if args && args[:from_date] && args[:to_date]
      @from_date, @to_date = args[:from_date], args[:to_date]
    end
    raise(ArgumentError, 'Please supply :from_date and :to_date') unless from_date && to_date
    key = "org#{model.id}_#{from_date.strftime(timestamp_format)}_#{to_date.strftime(timestamp_format)}"
    if key.include?(full_month_cache_stamp(from_date))
      if usage = model.usages.where(year: from_date.year, month: from_date.month).first
        return usage.usage_data
      else
        usage_data = fetch_usage_from_cache(key)
        model.usages.create(year: from_date.year, month: from_date.month, usage_data: usage_data)
        usage_data
      end
    else
      fetch_usage_from_cache(key)
    end
  end

  def fetch_usage_from_cache(key)
    Rails.cache.fetch(key, expires_in: 30.days) do
      model.tenants.inject({}) do |acc, tenant|
        acc[tenant] = {
          instance_results: Billing::Instances.usage(tenant.uuid, from_date, to_date),
          volume_results: Billing::Volumes.usage(tenant.uuid, from_date, to_date),
          image_results: Billing::Images.usage(tenant.uuid, from_date, to_date),
          ip_quota_results: Billing::IpQuotas.usage(tenant.uuid, from_date, to_date),
          object_storage_results: Billing::StorageObjects.usage(tenant.uuid, from_date, to_date)
        }
        acc
      end
    end
  end

  def instance_total(tenant_id, flavor_id=nil)
    usage_data.each do |tenant, results|
      if(tenant_id == tenant.id)
        results = results[:instance_results]
        if flavor_id
          results = results.select{|i| i[:flavor][:flavor_id] == flavor_id}
        end
        return results.collect{|i| i[:cost]}.sum
      end
    end
    return 0
  end

  def volume_total(tenant_id)
    usage_data.each do |tenant, results|
      if(tenant_id == tenant.id)
        return results[:volume_results].collect{|i| i[:cost]}.sum
      end
    end
    return 0
  end

  def image_total(tenant_id)
    usage_data.each do |tenant, results|
      if(tenant_id == tenant.id)
        return results[:image_results].collect{|i| i[:cost]}.sum
      end
    end
    return 0
  end

  def ip_quota_total(tenant_id)
    daily_rate = ((RateCard.ip_address * 12) / 365.0).round(2)
    usage_data.collect do |tenant, results|
      if(tenant_id == tenant.id)
        if results[:ip_quota_results].none?
          quota = tenant.quota_set['network']['floatingip'].to_i - 1
          ((((to_date - from_date) / 60.0) / 60.0) / 24.0).round * daily_rate * quota
        else
          start = from_date
          cost = results[:ip_quota_results].collect do |quota|
            period = ((((quota.recorded_at - start) / 60.0) / 60.0) / 24.0).round
            start = quota.recorded_at
            total_rate = (period * daily_rate)
            q = quota.previous ? quota.previous : 1
            (q - 1) * total_rate
          end.sum

          q = results[:ip_quota_results].last.quota - 1
          period = ((((to_date - results[:ip_quota_results].last.recorded_at) / 60.0) / 60.0) / 24.0).round
          total_rate = (period * daily_rate)
          cost += (q * total_rate)
          cost
        end
      end
    end.compact.sum
  end

  def object_storage_total(tenant_id)
    usage_data.each do |tenant, results|
      if(tenant_id == tenant.id)
        return (results[:object_storage_results] * RateCard.object_storage).nearest_penny
      end
    end
    return 0
  end

  def total(tenant_id)
    [
      instance_total(tenant_id), volume_total(tenant_id),
      image_total(tenant_id),
      ip_quota_total(tenant_id), 
      object_storage_total(tenant_id)
    ].sum
  end

  def sub_total
    model.tenants.collect{|t| total(t.id)}.sum
  end

  def discounts?
    !!active_discount
  end

  def discount_percent
    active_discount ? active_discount.voucher.discount_percent : 0.0
  end

  def active_discount
    model.active_vouchers(from_date, to_date).first
  end

  def tax_percent
    20
  end

  def grand_total
    return sub_total unless discounts?
    v = active_discount
    voucher_start = v.created_at
    voucher_end = v.expires_at

    totals = []
    
    # Calculate the part of the month that needs a discount
    from = (voucher_start < from_date) ? from_date : voucher_start
    to   = (voucher_end > to_date) ? to_date : voucher_end

    ud = UsageDecorator.new(model)

    ud.usage_data(from_date: from, to_date: to)
    discounted_total = ud.sub_total  * (1 - (discount_percent / 100.0))
    totals << discounted_total

    # Calculate the remainder at the start
    if from > from_date
      ud.usage_data(from_date: from_date, to_date: from)
      totals << ud.sub_total
    end

    # Calculate remainder at the end
    if to < to_date
      ud.usage_data(from_date: to, to_date: to_date)
      totals << ud.sub_total
    end

    totals.sum
  end

  def grand_total_plus_tax
    grand_total + (grand_total * 0.2)
  end

  private

  def timestamp_format
    "%Y%m%d%H"
  end
end