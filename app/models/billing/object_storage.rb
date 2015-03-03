module Billing
  class ObjectStorage < ActiveRecord::Base
    self.table_name = "billing_storage_objects"
    belongs_to :billing_sync, :class_name => "Billing::Sync", :foreign_key => 'sync_id'
  end
end