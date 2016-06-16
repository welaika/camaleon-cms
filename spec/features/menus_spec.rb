require "rails_helper"
describe "the Menus", js: true do
  login_success

  it "Menus list" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/appearances/nav_menus"
    expect(page).to have_css('#menu_content')
    within "#menu_items" do
      # post menus
      check("Sample Post")
      page.execute_script('$("#acc-post input").prop("checked", true)')
      page.execute_script('$("#acc-post").prev().find("input").prop("checked", true)')
      page.execute_script('$("#acc-post .add_links_to_menu").click()')
      wait_for_ajax

      # custom links
      all(".panel-collapse").last.click
      wait(3)
      within ".form-custom-link" do
        fill_in "external_label", with: "name link"
        fill_in "external_url", with: "http://mytest.com"
        find("#add_external_link").click
        wait_for_ajax
      end
    end

    within '#menus_list' do
      all('.delete_menu_item').each do |btn|
        btn.click
        page.driver.browser.switch_to.alert.accept
        wait_for_ajax
      end
    end

  end

  it "Menus Create and Delete" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/appearances/nav_menus"
    page.execute_script('$("#switch_nav_menu_form .btn-danger").click()')
    page.driver.browser.switch_to.alert.accept
    expect(page).to have_css('.alert-success')
  end

end