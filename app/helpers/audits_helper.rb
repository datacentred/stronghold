module AuditsHelper
  def audit_detail(audit)
    details = ''
    if audit.action == 'update'
      details = audit.audited_changes.collect do |k,v|
        previous_val = try_translate_permissions(k,v[0])
        current_val  = try_translate_permissions(k,v[1])
        "#{t(k.underscore.to_sym).capitalize.humanize} #{t(:is_now)} '#{current_val}' (#{t(:used_to_be)} '#{previous_val}')"
      end.join '. '
    else
      details = audit.audited_changes.collect do |k,v|
        val = try_translate_permissions(k,v)
        "'#{t(k.underscore.to_sym).capitalize.humanize}': '#{val}'"
      end.join ', '
    end
    details += '.'
  end

  def audit_colour(audit)
    case audit.action
    when 'create'
      'text-success'
    when 'destroy'
      'text-danger'
    when 'start'
      'text-success'
    when 'stop'
      'text-danger'
    else
      'text-info'
    end
      
  end

  def try_translate_permissions(k,v)
    if k.underscore.to_sym == :permissions
      vals = [v].flatten.map do |v|
        t("can_#{v.underscore.gsub('.','_').to_sym}", default: v)
      end
      r(vals)
    else
      r(v)
    end
  end
end