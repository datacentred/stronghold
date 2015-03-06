module Billing
  class Image < ActiveRecord::Base
    self.table_name = "billing_images"

    validates :image_id, uniqueness: true

    has_many :image_states
    
    scope :active, -> { all.select(&:active?) }

    def active?
      latest_state = image_states.order('recorded_at').last
      latest_state ? Billing::Images.billable?(latest_state.event_name) : true
    end

    def created_at
      image_states.where(event_name: 'image.update').order('recorded_at').first.try(:recorded_at) { nil }
    end

    def deleted_at
      image_states.where(event_name: 'image.delete').order('recorded_at').first.try(:recorded_at) { nil }
    end

    def latest_size
      image_states.order('recorded_at').last.try(:size) { nil }
    end
  end
end