require 'test_helper'

class TestModel
  include UsageHelper
  include Rails.application.routes.url_helpers

  def current_user
    @user ||= User.make(organization: Organization.make(created_at: signed_up))
  end

  def current_organization
    current_user.organization
  end

  def signed_up
    Time.parse('2014-01-01')
  end

  def params
    {
      month: Date.today.month,
      year: Date.today.year
    }
  end
end

class UsageHelperTest < CleanTest
  def setup
    @model = TestModel.new
  end

  def test_usages_for_select
    Timecop.freeze(Time.parse('2014-03-02')) do
      options = "<option selected=\"selected\" value=\"/account/usage?month=3&amp;year=2014\">March 2014</option>\n<option value=\"/account/usage?month=2&amp;year=2014\">February 2014</option>\n<option value=\"/account/usage?month=1&amp;year=2014\">January 2014</option>"
      assert_equal options, @model.usages_for_select(@model.current_organization)
    end

    Timecop.freeze(Time.parse('2014-01-31')) do
      options = "<option selected=\"selected\" value=\"/account/usage?month=1&amp;year=2014\">January 2014</option>"
      assert_equal options, @model.usages_for_select(@model.current_organization)
    end
  end

  def test_billing_range
    range = @model.billing_range(@model.current_organization)
    assert_equal @model.current_organization.created_at.beginning_of_month,
                 range.last
    assert_equal Date.today.end_of_month, range.first
    Timecop.freeze(Time.now + 2.years + 3.months) do
      range = @model.billing_range(@model.current_organization)
      assert_equal @model.current_organization.created_at.beginning_of_month,
                 range.last
      assert_equal Date.today.end_of_month, range.first
    end
  end

  def test_state_with_icon
    assert_equal "<i class='fa fa-play text-success'></i> Active", @model.state_with_icon('active')
    assert_equal "<i class='fa fa-pause'></i> Stopped", @model.state_with_icon('stopped')
    assert_equal "<i class='fa fa-eject text-danger'></i> Terminated", @model.state_with_icon('terminated')
    assert_equal 'foom!', @model.state_with_icon('foom!')
  end

end
