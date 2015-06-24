class FraudCheck

  attr_reader :customer_signup

  def initialize(customer_signup)
    @customer_signup = customer_signup
  end

  def request_fields
    signup_fields = {
      :client_ip => customer_signup.real_ip, 
      :forwarded_ip => customer_signup.forwarded_ip,
      :email => customer_signup.email,
      :user_agent => customer_signup.user_agent,
      :accept_language => customer_signup.accept_language
    }
    if customer_signup.organization
      org_fields = {
        :city => customer_signup.organization.billing_city, 
        :postal => customer_signup.organization.billing_postcode, 
        :country => customer_signup.organization.billing_country, 
        :shipping_address => [customer_signup.organization.billing_address1, customer_signup.organization.billing_address2].join("\n"),
        :shipping_city => customer_signup.organization.billing_city, 
        :shipping_postal => customer_signup.organization.billing_postcode, 
        :shipping_country => customer_signup.organization.billing_country, 
      }
      signup_fields.merge(org_fields)
    end
    signup_fields
  end

  def response_fields
    response.attributes
  end

  def suspicious?(force_new_response: false)
    Rails.cache.delete("fraud_check_#{customer_signup.id}") if force_new_response
    return true if response_fields[:risk_score] > 5
    false
  end

  private

  def response
    Rails.cache.fetch("fraud_check_#{customer_signup.id}", expires_in: 7.days) do
      request = Maxmind::Request.new(request_fields)
      request.process!
    end
  end
end

