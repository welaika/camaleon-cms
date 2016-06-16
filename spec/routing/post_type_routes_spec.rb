require "rails_helper"

RSpec.describe "routes for Post Types", :type => :routing do
  it "routes for /test-post-type" do
    post_type = create_test_post_type(slug: 'test-post-type')
    expect(get("/test-post-type")).to route_to("camaleon_cms/frontend#post_type", post_type_id: post_type.id)
  end
end