require_relative '../acceptance_test_helper'

class UserMenuTests < CapybaraTestCase
  
  def test_user_menu_contents
    visit('/')
    find('button#user-menu').click

    sleep(1)

    within('ul.dropdown-menu') do
      assert find(:xpath, "//a[@href='#{support_profile_path}']")
      assert find(:xpath, "//a[@href='#{support_edit_organization_path}']")
      assert find(:xpath, "//a[@href='#{support_audits_path}']")
      assert find(:xpath, "//a[@href='#{session_path(User.first)}']")
    end
  end

  def test_user_can_logout
    visit('/')
    find('button#user-menu').click
    AlertConfirmer.accept_confirm_from do
      find(:xpath, "//a[@href='#{session_path(User.first)}']").click
    end

    sleep(2)
    
    within('#sign-in') do
      assert has_content?('Sign In')
    end
    
  end
  
end