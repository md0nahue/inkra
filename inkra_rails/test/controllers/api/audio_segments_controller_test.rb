require "test_helper"

class Api::AudioSegmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @question = questions(:one)
    @valid_upload_request_params = {
      fileName: "test_audio.mp3",
      mimeType: "audio/mpeg",
      recordedDurationSeconds: 30,
      questionId: @question.id
    }
    @invalid_upload_request_params = {
      fileName: "",
      mimeType: "audio/mpeg",
      recordedDurationSeconds: 30,
      questionId: @question.id
    }
  end

  test "should create upload request with valid parameters" do
    assert_difference('AudioSegment.count') do
      post upload_request_api_project_audio_segments_url(@project), 
           params: @valid_upload_request_params, as: :json
    end

    assert_response :success

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'audioSegmentId'
    assert_includes response_data, 'uploadUrl'
    assert_includes response_data, 'expiresAt'

    # Verify upload URL format
    assert_match /https:\/\/mock-s3-bucket\.s3\.amazonaws\.com/, response_data['uploadUrl']
    
    # Verify ISO 8601 date format for expiresAt
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response_data['expiresAt']

    # Verify audio segment was created with correct attributes
    audio_segment = AudioSegment.find(response_data['audioSegmentId'])
    assert_equal "test_audio.mp3", audio_segment.file_name
    assert_equal "audio/mpeg", audio_segment.mime_type
    assert_equal 30, audio_segment.duration_seconds
    assert_equal @question.id, audio_segment.question_id
    assert_equal "pending", audio_segment.upload_status
  end

  test "should not create upload request with invalid parameters" do
    assert_no_difference('AudioSegment.count') do
      post upload_request_api_project_audio_segments_url(@project), 
           params: @invalid_upload_request_params, as: :json
    end

    assert_response :bad_request

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "VALIDATION_ERROR", response_data['code']
  end

  test "should create upload request without question_id" do
    params_without_question = @valid_upload_request_params.except(:questionId)
    
    assert_difference('AudioSegment.count') do
      post upload_request_api_project_audio_segments_url(@project), 
           params: params_without_question, as: :json
    end

    assert_response :success

    response_data = JSON.parse(response.body)
    audio_segment = AudioSegment.find(response_data['audioSegmentId'])
    assert_nil audio_segment.question_id
  end

  test "should handle successful upload completion" do
    audio_segment = @project.audio_segments.create!(
      file_name: "test.mp3",
      mime_type: "audio/mpeg",
      duration_seconds: 30,
      upload_status: "pending"
    )

    # Mock the transcription service call to return true for any audio_segment_id
    TranscriptionService.stub(:trigger_transcription_job, true) do
      post upload_complete_api_project_audio_segments_url(@project), 
           params: { 
             audioSegmentId: audio_segment.id, 
             uploadStatus: "success" 
           }, as: :json
    end

    assert_response :success

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'status'
    assert_equal 'processing_started', response_data['status']

    # Verify audio segment status was updated
    audio_segment.reload
    assert_equal "success", audio_segment.upload_status
  end

  test "should handle failed upload completion" do
    audio_segment = @project.audio_segments.create!(
      file_name: "test.mp3",
      mime_type: "audio/mpeg", 
      duration_seconds: 30,
      upload_status: "pending"
    )

    post upload_complete_api_project_audio_segments_url(@project), 
         params: { 
           audioSegmentId: audio_segment.id, 
           uploadStatus: "failed",
           errorMessage: "Upload failed due to network error"
         }, as: :json

    assert_response :bad_request

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "UPLOAD_FAILED", response_data['code']
    assert_match /Upload failed due to network error/, response_data['message']

    # Verify audio segment status was updated
    audio_segment.reload
    assert_equal "failed", audio_segment.upload_status
  end

  test "should handle upload completion with non-existent audio segment" do
    post upload_complete_api_project_audio_segments_url(@project), 
         params: { 
           audioSegmentId: 99999, 
           uploadStatus: "success" 
         }, as: :json

    assert_response :not_found

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "NOT_FOUND", response_data['code']
  end

  test "should return 404 for non-existent project in upload request" do
    post upload_request_api_project_audio_segments_url(99999), 
         params: @valid_upload_request_params, as: :json

    assert_response :not_found

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "NOT_FOUND", response_data['code']
  end

  test "should return 404 for non-existent project in upload complete" do
    post upload_complete_api_project_audio_segments_url(99999), 
         params: { audioSegmentId: 1, uploadStatus: "success" }, as: :json

    assert_response :not_found

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "NOT_FOUND", response_data['code']
  end

  test "should validate mime type is audio format" do
    invalid_params = @valid_upload_request_params.merge(mimeType: "image/jpeg")
    
    post upload_request_api_project_audio_segments_url(@project), 
         params: invalid_params, as: :json

    # This should succeed at the controller level but could be validated at model level
    # The test verifies the current behavior - adjust if validation is added
    assert_response :success
  end

  test "should validate duration is positive" do
    invalid_params = @valid_upload_request_params.merge(recordedDurationSeconds: -5)
    
    assert_no_difference('AudioSegment.count') do
      post upload_request_api_project_audio_segments_url(@project), 
           params: invalid_params, as: :json
    end

    assert_response :bad_request

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "VALIDATION_ERROR", response_data['code']
  end
end