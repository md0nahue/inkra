require "test_helper"

class Api::TranscriptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
  end

  test "should get transcript for project" do
    get transcript_api_project_url(@project)
    assert_response :success
  end
end
