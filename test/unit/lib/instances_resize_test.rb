require 'test_helper'

class MockServers
  def get(instance_id); nil; end
end

class TestInstancesResize < Minitest::Test
  def setup
    @from = Time.parse("2015-07-23 08:00:00")
    @to = Time.parse("2015-07-23 18:00:00")
    @tenant = Tenant.make!(name: 'datacentred', uuid: 'ed4431814d0a40dc8f10f5ac046267e9')
    @events = JSON.parse(File.read(File.expand_path("../../../../fixtures/dumps/resize_instance.json", __FILE__)))
    @servers_mock = OpenStruct.new(servers: MockServers.new)
    load_instance_flavors
  end

  def test_calculation_of_cost_for_unresized_instance
    Billing.stub(:fetch_samples, @events) do
      Fog::Compute.stub(:new, @servers_mock) do
        Billing::Instances.sync!(@from, @to, Billing::Sync.create(started_at: Time.now))
        Billing::Instance.all.each{|i| i.update_attributes(arch: 'x86_64')}
        instance = Billing::Instance.find_by_instance_id("68bd37fc-5e51-4bee-802b-a748fb1543da")
        instance.instance_states.create(recorded_at: Time.parse("2015-06-17 08:17:41"), state: 'active', sync_id: Billing::Sync.first.id, flavor_id: instance.flavor_id)

        # 10 billable hours total, at 0.0353
        assert_equal 0.35, Billing::Instances.cost(instance, @from, @to).round(2)
      end
    end   
  end

  def test_calculation_of_cost_for_resized_instance
    # Instance starts as 2x2 (billed at 0.0353)
    # and becomes 8x16 (billed at 0.2817)  
    Billing.stub(:fetch_samples, @events) do
      Fog::Compute.stub(:new, @servers_mock) do
        Billing::Instances.sync!(@from, @to, Billing::Sync.create(started_at: Time.now))
        instance = Billing::Instance.find_by_instance_id("b246c075-36d8-45ee-a8f5-a44c15158dd9")

        # Between 08:55 and 11:12 this machine was 2x2 (billed at 0.0353)
        # Between 11:22 and 12:46 this machine was 8x16 (billed at 0.2817)
        #
        # Logically, the cost should be 2.28 x 0.0353 + 1.55 * 0.2817
        # i.e. 0.517119, about 52p
        assert_equal 0.52, Billing::Instances.cost(instance, @from, @to).round(2)
      end
    end
  end

  def teardown
    DatabaseCleaner.clean
  end

end
