Dir[File.join(File.dirname(__FILE__), 'notifications', '*.rb')].each {|file| require file }

module Notifications

  def self.notifiers
    Notifications.constants
  end

  # Notify synchronously
  def self.notify!(key, message)
    WebMock.allow_net_connect! if Rails.env.test?
    key = key.to_s
    notifiers.each do |n|
      begin
        o = "Notifications::#{n.to_s}".constantize
        raise ArgumentError, "Unknown settings: #{key}" unless o.settings[key]
        m = "#{o.settings[key]['prefix']} #{message}" if o.settings[key]['prefix']
        o.send(:notify, *[key, m])
      rescue StandardError => e
        Honeybadger.notify(e)
      end
    end
  ensure
    WebMock.disable_net_connect! if Rails.env.test?
  end

  # Notify asynchronously
  def self.notify(key, message)
    SendNotificationJob.perform_later(key, message)
  end

end