require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root page is available" do
    get root_url
    assert_response :success
    assert_includes response.body, "BerlinBikeCountExplorer"
    assert_includes response.body, "Explorer"
  end
end
