namespace :stronghold do
  desc "Sync an organization with Ceph REFERENCE=reference"
  task :sync_with_ceph => :environment do
    if ENV['REFERENCE'].blank?
      puts 'Usage: rake stronghold:sync_with_ceph REFERENCE=xxx'
      exit
    end
    if(organization = Organization.find_by_reference(ENV['REFERENCE']))
      organization.tenants.each do |tenant|
        unless Ceph::User.exists?('uid' => tenant.uuid)
          Ceph::User.create 'uid' => tenant.uuid, 'display-name' => tenant.reference
          puts "Added a Ceph user for tenant #{tenant.reference}"
        end
      end
      organization.users.each do |user|
        credentials = Fog::Identity.new(OPENSTACK_ARGS).list_ec2_credentials(user.uuid).body['credentials']
        tenants_with_creds = credentials.collect{|c| c['tenant_id']}
        organization.tenants.each do |tenant|
          next if tenants_with_creds.include?(tenant.uuid)
          credential = Fog::Identity.new(OPENSTACK_ARGS).create_ec2_credential(user.uuid, tenant.uuid).body['credential']
          Ceph::UserKey.create 'uid' => tenant.uuid, 'access-key' => credential['access'], 'secret-key' => credential['secret']
          puts "Added an EC2 credential for tenant #{tenant.reference} for user #{user.name}"
        end
      end
      puts 'OK'
    else
      puts "Couldn't find an organization with reference #{ENV['REFERENCE']}"
    end
  end
end