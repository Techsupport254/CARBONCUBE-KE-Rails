require "test_helper"

class EmailOtpsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get email_otps_create_url
    assert_response :success
  end

  test "should get verify" do
    get email_otps_verify_url
    assert_response :success
  end
end
