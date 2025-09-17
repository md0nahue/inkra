require 'rails_helper'

RSpec.describe Api::AudioSegmentsController, type: :controller do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:audio_segment) { create(:audio_segment, project: project, upload_status: 'success') }

  before do
    # Mock authentication by stubbing the controller's current_user method
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authenticate_api_request!).and_return(true)
  end

  describe 'GET #playback_url' do
    context 'with valid audio segment' do
      let(:mock_s3_client) { instance_double(Aws::S3::Client) }
      let(:mock_presigner) { instance_double(Aws::S3::Presigner) }
      let(:mock_url) { 'https://s3.amazonaws.com/bucket/audio_segments/123/test.m4a?signature=abc' }

      before do
        # Mock S3Service instead of the underlying AWS components
        mock_s3_service = instance_double(S3Service)
        allow(S3Service).to receive(:new).and_return(mock_s3_service)
        allow(mock_s3_service).to receive(:generate_playback_url).and_return(mock_url)
      end

      it 'returns playback URL for successfully uploaded segment' do
        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['playback_url']).to eq(mock_url)
        expect(json_response['expires_at']).to be_present
        expect(json_response['duration']).to eq(audio_segment.duration_seconds)
        expect(json_response['file_name']).to eq(audio_segment.file_name)
      end

      it 'calls S3Service with correct parameters' do
        mock_s3_service = instance_double(S3Service)
        allow(S3Service).to receive(:new).with(user).and_return(mock_s3_service)
        
        expect(mock_s3_service).to receive(:generate_playback_url).with(
          record_id: audio_segment.id,
          record_type: 'audio_segment',
          filename: audio_segment.file_name,
          content_type: audio_segment.mime_type,
          expires_in: 3600
        ).and_return(mock_url)

        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }
      end
    end

    context 'with transcribed audio segment' do
      let(:transcribed_segment) { create(:audio_segment, project: project, upload_status: 'transcribed') }
      let(:mock_url) { 'https://s3.amazonaws.com/bucket/test.m4a' }

      before do
        # Mock S3Service properly for transcribed segments
        mock_s3_service = instance_double(S3Service)
        allow(S3Service).to receive(:new).and_return(mock_s3_service)
        allow(mock_s3_service).to receive(:generate_playback_url).and_return(mock_url)
      end

      it 'allows playback for transcribed segments' do
        get :playback_url, params: {
          project_id: project.id,
          id: transcribed_segment.id
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with audio segment not ready for playback' do
      let(:pending_segment) { create(:audio_segment, project: project, upload_status: 'pending') }

      it 'returns not found error for pending segments' do
        get :playback_url, params: {
          project_id: project.id,
          id: pending_segment.id
        }

        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Audio segment not available for playback')
        expect(json_response['code']).to eq('SEGMENT_NOT_AVAILABLE')
      end
    end

    context 'with failed audio segment' do
      let(:failed_segment) { create(:audio_segment, project: project, upload_status: 'failed') }

      it 'returns not found error for failed segments' do
        get :playback_url, params: {
          project_id: project.id,
          id: failed_segment.id
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with non-existent audio segment' do
      it 'returns not found error' do
        get :playback_url, params: {
          project_id: project.id,
          id: 'non-existent'
        }
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Audio segment not found')
        expect(json_response['code']).to eq('SEGMENT_NOT_FOUND')
      end
    end

    context 'with audio segment from different project' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }
      let(:other_segment) { create(:audio_segment, project: other_project, upload_status: 'success') }

      it 'returns not found error due to user scoping' do
        get :playback_url, params: {
          project_id: project.id,
          id: other_segment.id
        }
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Audio segment not found')
        expect(json_response['code']).to eq('SEGMENT_NOT_FOUND')
      end
    end

    context 'when S3 presigned URL generation fails' do
      before do
        # Mock S3Service to raise an error
        mock_s3_service = instance_double(S3Service)
        allow(S3Service).to receive(:new).and_return(mock_s3_service)
        allow(mock_s3_service).to receive(:generate_playback_url).and_raise(StandardError, 'S3 error')
      end

      it 'returns internal server error' do
        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }

        expect(response).to have_http_status(:internal_server_error)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Unable to generate playback URL')
        expect(json_response['code']).to eq('PLAYBACK_URL_ERROR')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('Failed to generate playback URL: S3 error')

        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }
      end
    end

    context 'in development environment with S3 fallback' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        # Mock S3Service to simulate fallback behavior in development
        mock_s3_service = instance_double(S3Service)
        allow(S3Service).to receive(:new).and_return(mock_s3_service)
        allow(mock_s3_service).to receive(:generate_playback_url).and_return('https://development-mock-url.example.com')
      end

      it 'returns mock URL in development' do
        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['playback_url']).to eq('https://development-mock-url.example.com')
      end
    end

    context 'without authentication' do
      before do
        # Override the global authentication mock to return unauthorized
        allow(controller).to receive(:authenticate_api_request!).and_call_original
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it 'returns unauthorized' do
        get :playback_url, params: {
          project_id: project.id,
          id: audio_segment.id
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
