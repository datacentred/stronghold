Tenant.all.each {|t| Rails.cache.delete("quotas_for_#{t.uuid}") rescue nil}