module Billing
  class InstanceState < ActiveRecord::Base
    self.table_name = "billing_instance_states"

    after_save :touch_instance, on: :create

    belongs_to :billing_instance, :class_name => "Billing::Instance", :foreign_key => 'instance_id'
    belongs_to :billing_sync, :class_name => "Billing::Sync", :foreign_key => 'sync_id'

    belongs_to :instance_flavor, :class_name => "Billing::InstanceFlavor",
           :primary_key => 'flavor_id', :foreign_key => 'flavor_id'

    def rate(arch)
      arch = "x86_64" if arch == "None"
      flavor = instance_flavor ? instance_flavor : Billing::InstanceFlavor.find_by_flavor_id(billing_instance.flavor_id)
      flavor.rates.where(arch: arch).first.rate.to_f rescue nil
    end

    private

    def touch_instance
      billing_instance.update_attributes(terminated_at: recorded_at) if state == 'deleted'
      if billing_instance.started_at.nil?
        billing_instance.update_attributes(started_at: recorded_at)
      elsif(recorded_at < billing_instance.started_at)
        billing_instance.update_attributes(started_at: recorded_at)
      end
    end

  end
end