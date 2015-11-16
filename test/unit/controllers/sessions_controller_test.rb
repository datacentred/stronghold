require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
  setup do
    @user = User.make!(password: 'Password1')
    @organization        = @user.organization
  end

  test "can go to sign in path" do
    get :new
    assert_response :success
  end

  test "index redirects" do
    get :index
    assert_redirected_to root_path
  end

  test "cannot access new, index, create when logged in" do
    log_in(@user)
    @organization.stub(:has_payment_method?, true) do
      @organization.stub(:known_to_payment_gateway?, true) do
        [:new, :index, :create].each do |action|
          assert_raises(ActionController::RoutingError) do
            get action
          end
        end
      end
    end
  end

  test "can log out" do
    log_in(@user)
    assert session.keys.count > 1
    delete :destroy, id: @user.id
    assert_redirected_to sign_in_path
    assert_equal 1, session.keys.count
    assert_equal "You have been signed out.", session["flash"]["flashes"]["notice"]
  end

  test "admin user logs in successfully" do
    create_session(true, true, true) do
      post :create, user: {email: @user.email, password: 'Password1'}
      # puts @response.inspect
      assert_equal 'token', session[:token]
      assert_equal @user.id, session[:user_id]
      assert_in_delta Time.now.utc, session[:created_at], 1
      assert_redirected_to support_root_path
    end
  end

  test "admin user logs in and is redirected to the next uri" do
    create_session(true, true, true) do
      post :create, {user: {email: @user.email, password: 'Password1'}, next: support_profile_path}
      assert_redirected_to support_profile_path
    end
  end

  test "admin user fails login because password is wrong" do
    create_session(true, true, true, false) do
      post :create, user: {email: @user.email, password: 'Wrongpassword123'}
      assert_response :success
      assert_equal "Invalid credentials. Please try again.", session["flash"]["flashes"]["alert"]
    end
  end

  test "admin user logs in for the first time and adds the first card to the account" do
    create_session(false, false, true) do
      post :create, user: {email: @user.email, password: 'Password1'}
      assert_redirected_to new_support_card_path 
      # allows destroy without redirect
      delete :destroy, id: @user.id
      assert_redirected_to sign_in_path
    end
  end

  test "admin user redirected when payment method is failing" do
    create_session(true, false, true) do
      post :create, user: {email: @user.email, password: 'Password1'}
      @controller = Support::UsersController.new
      @controller.stub(:current_user, @user) do
        get :index
        assert_redirected_to support_manage_cards_path
        assert_equal "Please add a valid card to continue.", session["flash"]["flashes"]["alert"]
      end
    end
  end

  test "users gets logged out when session expires" do
    create_session(true, true, true) do
      post :create, user: {email: @user.email, password: 'Password1'}
      Timecop.freeze(Time.now.utc + 4.hours) do
        @controller = Support::UsersController.new
        @controller.stub(:current_user, @user) do
          get :index
          assert_response :redirect
        end
      end
    end
  end

  test "non admin user logs in when payment method is failing" do
    create_session(true, false, false) do
      post :create, user: {email: @user.email, password: 'Password1'}
      @controller = Support::UsersController.new
      @controller.stub(:current_user, @user) do
        get :index
        assert_redirected_to sign_in_path
        assert_equal "Payment method has expired. Please inform a user with admin rights.", session["flash"]["flashes"]["alert"]
      end
    end
  end

  test "blank credentials shows error" do
    create_session(true, true, true) do
      post :create, user: {email: '', password: ''}
      assert_response :success
      assert_equal "Invalid credentials. Please try again.", session["flash"]["flashes"]["alert"]
    end
  end

  private

  def log_in(user)
    session[:user_id]    = user.id
    session[:created_at] = Time.now.utc
    session[:token]      = SecureRandom.hex
  end

  def create_session(known, has_payment, admin, os_auth='token', &blk)
    @organization.stub(:known_to_payment_gateway?, known) do
      @organization.stub(:has_payment_method?, has_payment) do
        User.stub(:find_by_email, @user) do
          @user.stub(:authenticate_openstack, os_auth) do
            @user.stub(:organization, @organization) do
              @user.stub(:admin?, admin) do
                yield
              end
            end
          end
        end
      end
    end
  end
end
