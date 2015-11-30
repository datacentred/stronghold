require 'test_helper'

class Support::OrganizationsControllerTest < ActionController::TestCase
  setup do
    @user = User.make!
    @organization = @user.organization
    @organization.update_attributes self_service: false
    @organization2 = Organization.make!
    @role = Role.make!(organization: @organization, power_user: true)
    @user.update_attributes(roles: [@role])
    log_in(@user)
  end

  def assert_404(actions)
    actions.each do |verb, action, args|
      assert_raises(ActionController::RoutingError) do
        send verb, action, args
      end
    end
  end

  test "only power users get to do anything org related" do
    @user.update_attributes(roles: [])
    assert_404([
      [:get, :index, nil],[:patch, :update, {id: @organization.id}],
      [:post, :reauthorise, {id: @organization.id}],[:post, :close, {id: @organization.id}]
    ])
  end

  test "users can't change different orgs" do
    patch :update, {format: 'js', id: @organization2.id, organization: {name: 'foo'}}
    assert_response :unprocessable_entity
    refute assigns(:organization)
  end

  test "user can edit their own org" do
    get :index
    assert assigns(:organization)
    assert_template "support/organizations/organization"
    patch :update, {format: 'js', id: @organization.id, organization: {name: 'foo'}}
    assert response.body.include?('Saved')
  end

  test "User can reauthorise with right password" do
    @controller.stub(:reauthenticate, true, "UpperLower123") do
      post :reauthorise, password: "UpperLower123", format: 'json'
      assert json_response['success']
    end
  end

  test "User can't reauthorise with wrong password" do
    @controller.stub(:reauthenticate, false, "wrgon") do
      post :reauthorise, password: "wrgon", format: 'json'
      assert_response :unprocessable_entity
      refute json_response['success']
    end
  end

  test "User can't close account with wrong password" do
    @controller.stub(:reauthenticate, false, "wrgon") do
      post :close, password: "wrgon"
      assert_redirected_to support_edit_organization_path
    end
  end

  test "User can close account with right password" do
    mail_mock = Minitest::Mock.new
    mail_mock.expect(:deliver_later, true, [])
    @controller.stub(:reauthenticate, true, "UpperLower123") do
      @controller.stub(:offboard, true) do
        Ceph::User.stub(:update, true) do
          Mailer.stub(:goodbye, mail_mock) do
            post :close, password: "UpperLower123"
            assert Organization.first.disabled?
            refute session[:user_id]
            refute session[:token]
            assert_template :goodbye
          end
        end
      end
    end
    mail_mock.verify
  end

  test "Handles Ceph errors" do
    @controller.stub(:reauthenticate, true, "UpperLower123") do
      @controller.stub(:offboard, true) do
        Ceph::User.stub(:update, Proc.new{ raise Net::HTTPError.new(500, 'foo') }) do
          Honeybadger.stub(:notify, true) do
            post :close, password: "UpperLower123"
            assert_response :ok
            assert_template :goodbye
          end
        end
      end
    end
  end

  test "dc staff can't close account" do
    @organization.update_attributes(reference: 'datacentred')
    @controller.stub(:reauthenticate, true, "UpperLower123") do
      post :close, password: "UpperLower123"
      assert_redirected_to support_edit_organization_path
    end
  end

  def teardown
    DatabaseCleaner.clean
  end
end