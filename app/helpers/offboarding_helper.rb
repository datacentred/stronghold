module OffboardingHelper
  def offboard(tenant)
    return false unless tenant.respond_to?(:uuid) && tenant.uuid.is_a?(String)

    # Delete all instances to clear ports
    fog = Fog::Compute.new(OPENSTACK_ARGS)
    instances = fog.list_servers_detail(all_tenants: true).body['servers'].select{|s| s['tenant_id'] == tenant.uuid}.map{|s| s['id']}
    instances.each do |instance|
      fog.delete_server(instance)
    end

    images = fog.list_images_detail(tenant_id: tenant.uuid).body['images'].map{|i| i['id']}
    images.each do |image|
      begin
        fog.delete_image(image)
      rescue Excon::Errors::Error
      end
    end

    fog = Fog::Volume.new(OPENSTACK_ARGS)
    snapshots = fog.list_snapshots(true, :all_tenants => true).body['snapshots'].select{|s| s["os-extended-snapshot-attributes:project_id"] == tenant.uuid}.map{|s| s['id']}
    snapshots.each do |snapshot|
      fog.delete_snapshot(snapshot)
    end

    volumes = fog.list_volumes(true, :all_tenants => true).body['volumes'].select{|v| v["os-vol-tenant-attr:tenant_id"] == tenant.uuid}.map{|v| v['id']}
    volumes.each do |volume|
      fog.delete_volume(volume)
    end

    fog = Fog::Network.new(OPENSTACK_ARGS)
    routers  = fog.list_routers(tenant_id:  tenant.uuid).body['routers'].map{|r| r['id']}
    subnets  = fog.list_subnets(tenant_id:  tenant.uuid).body['subnets'].map{|s| s['id']}
    networks = fog.list_networks(tenant_id: tenant.uuid).body['networks'].map{|n| n['id']}

    # Iterate through routers and remove router interface
    routers.each do |router|
      subnets.each do |subnet|
        begin
          fog.remove_router_interface(router, subnet)
        rescue Fog::Network::OpenStack::NotFound
          # Ignore
        end
      end
    end

    ports    = fog.list_ports(tenant_id:    tenant.uuid).body['ports'].map{|p| p['id']}
    # Iterate through ports and delete all
    ports.each    {|p| fog.delete_port(p)}
    # Iterate through routers and delete all
    routers.each  {|r| fog.delete_router(r)}
    # Iterate through subnets and delete all
    subnets.each  {|s| fog.delete_subnet(s)}
    # Iterate through networks and delete all
    networks.each {|n| fog.delete_network(n)}

    true
  end
end
