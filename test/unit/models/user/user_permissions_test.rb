require 'test_helper'

class TestUserPermissions < Minitest::Test
  def setup
    @user = User.make
    @role = Role.make
  end

  def test_user_without_role_has_no_permissions
    Permissions.user.each do |permission_name,_|
      refute @user.has_permission? permission_name
    end
  end

  def test_user_with_power_user_role_has_all_permissions
    @role.update_attributes(power_user: true)
    @user.update_attributes(roles: [@role])
    Permissions.user.each do |permission_name,_|
      assert @user.has_permission? permission_name
    end
  end

  def test_user_with_single_role_has_permission_for_it_only
    sample_permission = Permissions.user.keys.sample
    @role.update_attributes(permissions: [sample_permission])
    @user.update_attributes(roles: [@role])
    Permissions.user.each do |permission_name,_|
      if permission_name == sample_permission
        assert @user.has_permission? permission_name
      else
        refute @user.has_permission? permission_name
      end
    end
  end

  def teardown
    DatabaseCleaner.clean  
  end
end