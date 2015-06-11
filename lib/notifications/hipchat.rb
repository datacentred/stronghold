require 'hipchat'

module Notifications
  class Hipchat
    def self.notify(key, message)
      key = key.to_s
      raise ArgumentError, "Unknown settings: #{key}" unless settings[key]
      if HIPCHAT_NOTIFICATIONS_ENABLED
        message = "#{prefix} #{message}" if settings[key][:prefix]
        client[settings[key]['room']].send(settings[key]['from'], message, {:notify => true}.merge(settings[key]['format']))  
      end
    end

    def self.settings
      HIPCHAT_NOTIFICATIONS_SETTINGS.dup
    end

    private

    def self.client
      HipChat::Client.new(Rails.application.secrets.hipchat_api_token)
    end
  end
end