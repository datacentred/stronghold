require 'test_helper'

class ResetsControllerTest < ActionController::TestCase
  setup do
    @user = User.make!(password: 'Password1')
  end

  test "Can't do anything if logged in" do
    log_in(@user)
    assert_404([
      [:get, :new, nil],
      [:get, :show, {id: 'foo'}],
      [:post, :create, {reset: {email: 'foo'}}],
      [:patch, :update, {id: 'foo', password: '12345678'}]
    ])
  end

  test "new loads and renders" do
    get :new
    assert_response :success
    assert_template :new
  end

  test "can create a new reset with a valid email" do
    post :create, reset: { email: @user.email }, format: 'js'
    assert_response :success
    assert @response.body.include? "check your email"
  end

  test "can't create a new reset with an invalid email" do
    post :create, reset: { email: 'foo' }, format: 'js'
    assert_response :unprocessable_entity
    assert @response.body.include? 'too short'
  end

  test "valid emails pretend to work if the address isn't found" do
    post :create, reset: { email: 'foo@bar.com' }, format: 'js'
    assert_response :success
    assert @response.body.include? "check your email"
  end

  test "can view a reset if it's still valid" do
    reset = Reset.create email: @user.email
    get :show, id: reset.token
    assert_response :success
    assert assigns(:reset)
    assert_template :show
  end

  test "can't view a reset if it doesn't exist" do
    assert_404 [[:get, :show, {id: 'fdsfds'}]]
  end

  test "can't view a reset if it's expired" do
    reset = Reset.create email: @user.email
    Timecop.freeze(Time.now + 1.month) do
      assert_404 [[:get, :show, {id: reset.token}]]
    end
  end

  test "can set a new password for a valid reset" do
    reset = Reset.create email: @user.email
    patch :update, id: reset.token, password: '12345678', format: 'js'
    assert_response 302
    assert @response.body.include? sign_in_path
  end

  test "can't set a new password for an invalid reset" do
    assert_404 [[:patch, :update, {id: 'foo', password: '12345678', format: 'js'}]]
  end

  test "can't set a new password for an expired reset" do
    reset = Reset.create email: @user.email
    Timecop.freeze(Time.now + 1.month) do
      assert_404 [[:patch, :update, {id: reset.token, password: '12345678', format: 'js'}]]
    end
  end

  test "can't reset password with invalid password" do
    reset = Reset.create email: @user.email
    patch :update, id: reset.token, password: '', format: 'js'
    assert_response :unprocessable_entity
    assert @response.body.include? 'too short'
  end

end