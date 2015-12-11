module Sanity
  def self.check
    results = current_sanity_state.dup
    key = "previous_sanity_state"
    cache = Rails.cache
    previous_results = cache.read(key)
    if previous_results
      duplicates = compare_sanity_states(previous_results, results)
      cache.write(key, results, expires_in: 3.days)
      return duplicates.merge(:sane => duplicates.values.none?(&:present?))
    else
      cache.write(key, results, expires_in: 3.days)
      return {sane: true}
    end
  end

  def self.current_sanity_state
    {
      missing_instances: build_missing_collection_hash(missing_instances, :instance_id),
      missing_volumes: build_missing_collection_hash(missing_volumes, :volume_id),
      missing_images: build_missing_collection_hash(missing_images, :image_id),
      new_instances: Hash[new_instances.collect{|key,value| [key, {name: value['name'], tenant_id: value['tenant_id']}]}]
    }
  end

  def self.missing_instances
    Billing::Instance.active.reject do |instance|
      if !live_instances.include?(instance.instance_id)
        false
      else
        from = instance.instance_states.order('recorded_at').first.recorded_at
        to   = instance.instance_states.order('recorded_at').last.recorded_at
        check_instance_state(live_instances[instance.instance_id]['status'].downcase,
                   instance.fetch_states(from, to).last.state.downcase)
      end
    end
  end

  def self.new_instances
    live_instances.reject do |instance,_|
      Billing::Instance.find_by_instance_id(instance) || instance_in_error_state(instance)
    end
  end

  def self.missing_volumes
    Billing::Volume.active.reject do |volume|
      begin
        OpenStackConnection.volume.get_volume_details(volume.volume_id)
      rescue Fog::Volume::OpenStack::NotFound
        false
      end
    end
  end

  def self.missing_images
    Billing::Image.active.reject do |image|
      live_images.include?(image.image_id)
    end
  end

  def self.build_missing_collection_hash(collection, id_method)
    Hash[collection.collect{|item| [item.send(id_method), {name: item.name, tenant_id: item.tenant_id}]}]
  end

  def self.compare_sanity_states(previous_results, results)
    Hash[results.collect do |key,value|
      [key, value.select{|item,_| previous_results[key][item]}]
    end]
  end

  def self.notify!(data)
    msg = Mailer.usage_sanity_failures(data).text_part.to_s
    ignore = "Content-Type: text/plain;\r\n charset=UTF-8\r\nContent-Transfer-Encoding: 7bit\r\n\r\n"
    msg.gsub! ignore, ''
    Notifications.notify(:sanity_check, msg)
  end

  def self.live_instances
    Rails.cache.fetch('sanity_live_instances', expires_in: 10.minutes) do
      Hash[OpenStackConnection.compute.list_servers_detail(:all_tenants => true).body['servers'].collect{|server| [server['id'], {'status' => server['status'].downcase, 'name' => server['name'], 'tenant_id' => server['tenant_id']}]}]
    end
  end

  def self.live_images
    Rails.cache.fetch('sanity_live_images', expires_in: 10.minutes) do
      OpenStackConnection.compute.list_images.body['images'].collect{|image| image['id']}
    end
  end

  def self.check_instance_state(live, recorded)
    if live.include?('rescue')
      return recorded.include?('rescue')
    else
      live == recorded
    end
  end

  def self.instance_in_error_state(instance)
    OpenStackConnection.compute.get_server_details(instance).body['server']['status'].downcase == 'error'
  rescue Fog::Compute::OpenStack::NotFound
    false
  end
end