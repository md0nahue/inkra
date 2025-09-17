require 'rails_helper'

RSpec.describe 'Api::AudioSegments', type: :request do
  include_context "with authenticated user"

  let(:project) { create(:project, user: current_user) }
  let(:question) { create(:question) }

  let(:valid_upload_params) do
    {
      fileName: "test_audio.mp3",
      mimeType: "audio/mpeg",
      recordedDurationSeconds: 120,
      questionId: question.id
    }
  end

  let(:invalid_upload_params) do
    {
      fileName: "",
      mimeType: "audio/mpeg",
      recordedDurationSeconds: 120,
      questionId: question.id
    }
  end

  describe 'POST /api/projects/:id/audio/upload-request' do
    context 'with valid parameters' do
      it 'creates a new audio segment' do
        expect {
          post "/api/projects/#{project.id}/audio/upload-request",
               params: valid_upload_params,
               headers: auth_headers
        }.to change(AudioSegment, :count).by(1)
        
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct response structure' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        expect(response_data).to include(
          'audioSegmentId', 'uploadUrl', 'expiresAt'
        )
        expect(response_data['audioSegmentId']).to be_a(Integer)
        expect(response_data['uploadUrl']).to be_a(String)
        expect(response_data['expiresAt']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end

      it 'creates audio segment with correct attributes' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        response_data = JSON.parse(response.body)
        audio_segment = AudioSegment.find(response_data['audioSegmentId'])
        
        expect(audio_segment.project).to eq(project)
        expect(audio_segment.question).to eq(question)
        expect(audio_segment.file_name).to eq("test_audio.mp3")
        expect(audio_segment.mime_type).to eq("audio/mpeg")
        expect(audio_segment.duration_seconds).to eq(120)
        expect(audio_segment.upload_status).to eq("pending")
      end

      it 'generates proper upload URL format' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        # In development, should return mock URL or real S3 URL
        expect(response_data['uploadUrl']).to match(/https:\/\//)
        expect(response_data['uploadUrl']).to include('audio_segments')
      end

      it 'sets expiration time to 1 hour from now' do
        freeze_time = Time.current
        travel_to(freeze_time) do
          post "/api/projects/#{project.id}/audio/upload-request",
               params: valid_upload_params,
               headers: auth_headers
        end
        
        response_data = JSON.parse(response.body)
        expires_at = Time.parse(response_data['expiresAt'])
        
        expect(expires_at).to be_within(1.minute).of(freeze_time + 1.hour)
      end
    end

    context 'with optional questionId' do
      let(:params_without_question) { valid_upload_params.except(:questionId) }

      it 'creates audio segment without question association' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: params_without_question,
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        audio_segment = AudioSegment.find(response_data['audioSegmentId'])
        
        expect(audio_segment.question).to be_nil
      end
    end

    context 'with invalid parameters' do
      it 'returns validation error' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: invalid_upload_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:bad_request)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('VALIDATION_ERROR')
        expect(response_data['details']).to have_key('field_errors')
      end

      it 'does not create audio segment' do
        expect {
          post "/api/projects/#{project.id}/audio/upload-request",
               params: invalid_upload_params,
               headers: auth_headers
        }.not_to change(AudioSegment, :count)
      end
    end

    context 'with invalid duration' do
      let(:negative_duration_params) do
        valid_upload_params.merge(recordedDurationSeconds: -5)
      end

      it 'returns validation error for negative duration' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: negative_duration_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:bad_request)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('VALIDATION_ERROR')
      end
    end

    context 'with non-existent project' do
      it 'returns not found error' do
        post "/api/projects/999999/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('NOT_FOUND')
      end
    end

    context 'with project belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }

      it 'returns not found error' do
        post "/api/projects/#{other_project.id}/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: valid_upload_params
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with AWS S3 configuration errors' do
      before do
        # Mock S3 client to raise an error
        allow_any_instance_of(Api::AudioSegmentsController).to receive(:generate_presigned_url)
          .and_raise(Aws::S3::Errors::ServiceError.new('', 'S3 error'))
      end

      it 'falls back to mock URL in development' do
        allow(Rails.env).to receive(:development?).and_return(true)
        
        post "/api/projects/#{project.id}/audio/upload-request",
             params: valid_upload_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['uploadUrl']).to include('mock-s3-bucket')
      end
    end
  end

  describe 'POST /api/projects/:id/audio/upload-complete' do
    let!(:audio_segment) do
      create(:audio_segment, project: project, upload_status: 'pending')
    end

    let(:success_params) do
      {
        audioSegmentId: audio_segment.id,
        uploadStatus: 'success'
      }
    end

    let(:failure_params) do
      {
        audioSegmentId: audio_segment.id,
        uploadStatus: 'failed',
        errorMessage: 'Network timeout occurred'
      }
    end

    context 'with successful upload' do
      it 'updates audio segment status and triggers transcription' do
        # Mock the TranscriptionService to avoid actual job enqueuing
        expect(TranscriptionService).to receive(:trigger_transcription_job).with(audio_segment.id)
        
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: success_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['message']).to eq('Audio segment processing initiated')
        expect(response_data['status']).to eq('processing_started')
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('success')
      end

      it 'enqueues transcription job' do
        allow(TranscriptionService).to receive(:trigger_transcription_job)
        
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: success_params,
             headers: auth_headers
        
        expect(TranscriptionService).to have_received(:trigger_transcription_job).with(audio_segment.id)
      end
    end

    context 'with failed upload' do
      it 'updates audio segment status to failed' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: failure_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:bad_request)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('UPLOAD_FAILED')
        expect(response_data['message']).to include('Network timeout occurred')
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('failed')
      end

      it 'does not trigger transcription for failed uploads' do
        expect(TranscriptionService).not_to receive(:trigger_transcription_job)
        
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: failure_params,
             headers: auth_headers
      end
    end

    context 'with failed upload but no error message' do
      let(:failure_params_no_message) do
        {
          audioSegmentId: audio_segment.id,
          uploadStatus: 'failed'
        }
      end

      it 'uses default error message' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: failure_params_no_message,
             headers: auth_headers
        
        response_data = JSON.parse(response.body)
        expect(response_data['message']).to eq('Upload failed')
      end
    end

    context 'with non-existent audio segment' do
      let(:invalid_params) do
        {
          audioSegmentId: 999999,
          uploadStatus: 'success'
        }
      end

      it 'returns not found error' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: invalid_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('NOT_FOUND')
      end
    end

    context 'with audio segment from different project' do
      let(:other_project) { create(:project, user: current_user) }
      let(:other_audio_segment) { create(:audio_segment, project: other_project) }
      
      let(:cross_project_params) do
        {
          audioSegmentId: other_audio_segment.id,
          uploadStatus: 'success'
        }
      end

      it 'returns not found error' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: cross_project_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with project belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }

      it 'returns not found error' do
        post "/api/projects/#{other_project.id}/audio/upload-complete",
             params: success_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: success_params
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when TranscriptionService fails to trigger' do
      before do
        allow(TranscriptionService).to receive(:trigger_transcription_job)
          .and_raise(StandardError, 'Queue service unavailable')
      end

      it 'still updates audio segment but returns error' do
        post "/api/projects/#{project.id}/audio/upload-complete",
             params: success_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:internal_server_error)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('INTERNAL_SERVER_ERROR')
        
        # Audio segment should still be updated
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('success')
      end
    end
  end

  describe 'error handling edge cases' do
    context 'with malformed request parameters' do
      it 'handles malformed JSON gracefully' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: "invalid json",
             headers: auth_headers.merge('Content-Type' => 'application/json')
        
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with very large file names' do
      let(:large_filename_params) do
        valid_upload_params.merge(fileName: 'a' * 1000 + '.mp3')
      end

      it 'handles large file names appropriately' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: large_filename_params,
             headers: auth_headers
        
        # Should either succeed or return appropriate validation error
        expect([200, 400]).to include(response.status)
      end
    end

    context 'with special characters in file names' do
      let(:special_chars_params) do
        valid_upload_params.merge(fileName: 'test file (1) [copy].mp3')
      end

      it 'handles special characters in file names' do
        post "/api/projects/#{project.id}/audio/upload-request",
             params: special_chars_params,
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        audio_segment = AudioSegment.find(response_data['audioSegmentId'])
        expect(audio_segment.file_name).to eq('test file (1) [copy].mp3')
      end
    end
  end

  describe 'GET /api/projects/:id/audio/:audioSegmentId/playback-url' do
    let(:audio_segment) { create(:audio_segment, project: project, upload_status: 'transcribed') }

    context 'with successful transcribed segment' do
      it 'returns playback URL and metadata' do
        get "/api/projects/#{project.id}/audio/#{audio_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('playbackUrl')
        expect(response_data).to have_key('expiresAt')
        expect(response_data).to have_key('duration')
        expect(response_data).to have_key('fileName')
        
        expect(response_data['playbackUrl']).to be_present
        expect(response_data['fileName']).to eq(audio_segment.file_name)
      end
    end

    context 'with successfully uploaded segment' do
      let(:uploaded_segment) { create(:audio_segment, project: project, upload_status: 'success') }

      it 'returns playback URL for uploaded segment' do
        get "/api/projects/#{project.id}/audio/#{uploaded_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['playbackUrl']).to be_present
      end
    end

    context 'with pending segment' do
      let(:pending_segment) { create(:audio_segment, project: project, upload_status: 'pending') }

      it 'returns not found error' do
        get "/api/projects/#{project.id}/audio/#{pending_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['message']).to eq('Audio segment not available for playback')
        expect(response_data['code']).to eq('SEGMENT_NOT_AVAILABLE')
      end
    end

    context 'with failed segment' do
      let(:failed_segment) { create(:audio_segment, project: project, upload_status: 'failed') }

      it 'returns not found error' do
        get "/api/projects/#{project.id}/audio/#{failed_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['message']).to eq('Audio segment not available for playback')
      end
    end

    context 'with non-existent audio segment' do
      it 'returns not found error' do
        get "/api/projects/#{project.id}/audio/99999/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with audio segment from different project' do
      let(:other_project) { create(:project, user: current_user) }
      let(:other_segment) { create(:audio_segment, project: other_project, upload_status: 'transcribed') }

      it 'returns not found error' do
        get "/api/projects/#{project.id}/audio/#{other_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with project belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }
      let(:other_segment) { create(:audio_segment, project: other_project, upload_status: 'transcribed') }

      it 'returns not found error' do
        get "/api/projects/#{other_project.id}/audio/#{other_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get "/api/projects/#{project.id}/audio/#{audio_segment.id}/playback-url"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with S3 configuration errors' do
      before do
        allow_any_instance_of(Api::AudioSegmentsController).to receive(:generate_playback_url).and_raise(StandardError, 'S3 error')
      end

      it 'returns internal server error' do
        get "/api/projects/#{project.id}/audio/#{audio_segment.id}/playback-url",
            headers: auth_headers

        expect(response).to have_http_status(:internal_server_error)
        
        response_data = JSON.parse(response.body)
        expect(response_data['message']).to eq('Unable to generate playback URL')
        expect(response_data['code']).to eq('PLAYBACK_URL_ERROR')
      end
    end
  end

  private

  def auth_headers
    {
      'Authorization' => "Bearer #{jwt_token_for(current_user)}",
      'Content-Type' => 'application/json'
    }
  end

  def jwt_token_for(user)
    # Mock JWT token generation
    "mock_jwt_token_for_user_#{user.id}"
  end
end