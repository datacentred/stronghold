module Billing
  module Images

    def self.sync!(from, to, sync)
      Project.with_deleted.each do |project|
        next unless project.uuid
        Billing.fetch_samples(project.uuid, "image", from, to).each do |image_id, samples|
          create_new_states(project.uuid, image_id, samples, sync)
        end
      end
    end

    def self.usage(project_id, from, to)
      images = Billing::Image.where(:project_id => project_id).to_a.compact.reject{|image| image.deleted_at && image.deleted_at < from}
      images = images.collect do |image|
        tb_hours = terabyte_hours(image, from, to)
        { terabyte_hours: tb_hours,
                                  cost: (tb_hours * RateCard.block_storage).nearest_penny,
                                  id: image.image_id,
                                  created_at: image.created_at,
                                  deleted_at: image.deleted_at,
                                  latest_size: terabytes_to_gigabytes(image.latest_size),
                                  name: image.name}
      end
      images.select{|i| i[:terabyte_hours] > 0}
    end

    def self.terabyte_hours(image, from, to)
      states = image.image_states.where(:recorded_at => from..to).order('recorded_at')
      previous_state = image.image_states.where('recorded_at < ?', from).order('recorded_at DESC').limit(1).first

      if states.any?
        if states.count > 1
          start = 0

          if previous_state
            if billable?(previous_state.event_name)
              start = seconds_to_whole_hours(states.first.recorded_at - from)
              start *= states.first.size
            end
          end

          previous = states.first
          middle = states.collect do |state|
            difference = 0
            if billable?(previous.event_name)
              difference = seconds_to_whole_hours(state.recorded_at - previous.recorded_at)
              difference *= state.size
            end
            previous = state
            difference
          end.sum

          ending = 0

          if(billable?(states.last.event_name))
            ending = seconds_to_whole_hours(to - states.last.recorded_at)
            ending *= states.last.size
          end

          return (start + middle + ending).round(2)
        else
          # Only one sample for this period
          if billable?(states.first.event_name)
            return (seconds_to_whole_hours(to - from) * states.first.size).round(2)
          else
            return 0
          end
        end
      else
        if previous_state && billable?(previous_state.event_name)
          return (seconds_to_whole_hours(to - from) * previous_state.size).round(2)
        else
          return 0
        end
      end
    end

    def self.billable?(event)
      event != 'image.delete'
    end

    def self.seconds_to_whole_hours(seconds)
      (seconds.to_f / Billing::SECONDS_TO_HOURS).ceil
    end

    def self.bytes_to_terabytes(bytes)
      bytes.to_f / 1_099_511_627_776
    end

    def self.terabytes_to_gigabytes(terabytes)
      terabytes.to_f * 1024.0
    end

    def self.create_new_states(project_id, image_id, samples, sync)
      first_sample_metadata = samples.first['resource_metadata']
      unless Billing::Image.find_by_image_id(image_id)
        image = Billing::Image.create(image_id: image_id, project_id: project_id, name: first_sample_metadata["name"])
        unless samples.any? {|s| s['resource_metadata']['event_type']}
          # This is a new image and we don't know its current size
          # Attempt to find out
          if(os_image = OpenStackConnection.image.images.get(image_id))
            image.image_states.create recorded_at: Time.now, size: bytes_to_terabytes(os_image.size.to_i),
                                            event_name: 'ping', billing_sync: sync,
                                            message_id: SecureRandom.uuid
          end
        end
      end
      billing_image = Billing::Image.find_by_image_id(image_id)

      # Catch renames
      if(billing_image.name != first_sample_metadata["name"])
        billing_image.update_attributes(name: first_sample_metadata["name"])
      end

      samples.collect do |s|
        if s['resource_metadata']['event_type']
          Billing::ImageState.create image_id: billing_image.id, recorded_at: Time.zone.parse("#{s['recorded_at']} UTC"),
                                      size: bytes_to_terabytes(s['resource_metadata']['size'].to_i),
                                      event_name: s['resource_metadata']['event_type'], billing_sync: sync,
                                      message_id: s['message_id']
        end
      end
    end

  end
end
