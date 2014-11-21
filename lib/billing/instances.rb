module Billing
  module Instances

    def self.sync!
      to_time = nil
      Time.use_zone('London') { to = Time.now }
      ActiveRecord::Base.transaction do
        from = Billing::Sync.last.completed_at
        to   = Time.now
        Tenant.all.each do |tenant|
          next unless tenant.uuid
          fetch_samples(tenant.uuid, from, to).each do |instance_id, samples|
            create_new_states(tenant.uuid, instance_id, samples)
          end
        end
        Billing::Sync.create completed_at: DateTime.now
      end
    end

    def self.usage(tenant_id, from, to)
      instances = Billing::Instance.where(:tenant_id => tenant_id).to_a.compact
      total = instances.inject({}) do |usage, instance|
        usage[instance.instance_id] = {billable_seconds: seconds(instance, from, to),
                                       name: instance.name, flavor_id: instance.flavor_id,
                                       image_id: instance.image_id}
        usage
      end
      total.select{|k,v| v[:billable_seconds] > 0}
    end

    def self.seconds(instance, from, to)
      states = instance.instance_states.where(:recorded_at => from..to).order('recorded_at')
      previous_state = instance.instance_states.where('recorded_at < ?', from).order('recorded_at DESC').limit(1).first

      if states.any?
        if states.count > 1
          start = 0

          if previous_state
            if billable?(previous_state.state)
              start = (states.first.recorded_at - from)
            end
          end

          previous = states.first
          middle = states.collect do |state|
            difference = 0
            if billable?(previous.state)
              difference = state.recorded_at - previous.recorded_at
            end
            previous = state
            difference
          end.sum

          ending = 0

          if(billable?(states.last.state))
            ending = (to - states.last.recorded_at)
          end

          return (start + middle + ending).round
        else
          # Only one sample for this period
          if billable?(states.first.state)
            return (to - from).round
          else
            return 0
          end
        end
      else
        if previous_state && billable?(previous_state.state)
          return (to - from).round
        else
          return 0
        end
      end
    end

    def self.billable?(state)
      !["building", "stopped", "shutoff", "deleted"].include?(state.downcase)
    end

    def self.fetch_samples(tenant_id, from, to)
      timestamp_format = "%Y-%m-%dT%H:%M:%S"
      options = [{'field' => 'timestamp', 'op' => 'ge', 'value' => from.strftime(timestamp_format)},
                 {'field' => 'timestamp', 'op' => 'lt', 'value' => to.strftime(timestamp_format)},
                 {'field' => 'project_id', 'value' => tenant_id, 'op' => 'eq'}]
      tenant_samples = Fog::Metering.new(OPENSTACK_ARGS).get_samples("instance", options).body
      tenant_samples.group_by{|s| s['resource_id']}
    end

    def self.create_new_states(tenant_id, instance_id, samples)
      unless Billing::Instance.find_by_instance_id(instance_id)
        first_sample_metadata = samples.first['resource_metadata']
        flavor_id = first_sample_metadata["instance_flavor_id"] ? first_sample_metadata["instance_flavor_id"] : first_sample_metadata["flavor.id"]
        instance = Billing::Instance.create(instance_id: instance_id, tenant_id: tenant_id, name: first_sample_metadata["display_name"],
                                 flavor_id: flavor_id, image_id: first_sample_metadata["image_ref_url"].split('/').last)
        unless samples.any? {|s| s['resource_metadata']['event_type']}
          # This is a new instance and we don't know its current state.
          # Attempt to find out
          if(os_instance = Fog::Compute.new(OPENSTACK_ARGS).servers.get(instance_id))
            instance.instance_states.create recorded_at: DateTime.now, state: os_instance.state.downcase
          end
        end
      end
      billing_instance_id = Billing::Instance.find_by_instance_id(instance_id).id
      samples.collect do |s|
        if s['resource_metadata']['event_type']
          Billing::InstanceState.create instance_id: billing_instance_id, recorded_at: s['recorded_at'],
                                        state: s['resource_metadata']['state'] ? s['resource_metadata']['state'].downcase : 'active'
        end
      end
    end

  end
end
