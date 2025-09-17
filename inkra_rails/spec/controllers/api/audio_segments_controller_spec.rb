require 'rails_helper'

RSpec.describe Api::AudioSegmentsController, type: :controller do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:audio_segment) { create(:audio_segment, project: project) }

  before do
    allow(JwtService).to receive(:decode_token).and_return({ 'user_id' => user.id, 'type' => 'access' })
    request.headers['Authorization'] = 'Bearer fake_token'
  end

  describe '#playback_url', :vcr do
    context 'when audio segment is successfully uploaded' do
      before do
        audio_segment.update!(upload_status: 'success')
      end

      it 'returns playback URL for the audio segment' do
        get :playback_url, params: { 
          id: project.id, 
          audioSegmentId: audio_segment.id 
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('playbackUrl')
        expect(json_response).to have_key('expiresAt')
        expect(json_response).to have_key('duration')
        expect(json_response).to have_key('fileName')
        expect(json_response['duration']).to eq(audio_segment.duration_seconds)
        expect(json_response['fileName']).to eq(audio_segment.file_name)
      end
    end

    context 'when audio segment is transcribed' do
      before do
        audio_segment.update!(upload_status: 'transcribed')
      end

      it 'returns playback URL for the audio segment' do
        get :playback_url, params: { 
          id: project.id, 
          audioSegmentId: audio_segment.id 
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when audio segment is not available for playback' do
      before do
        audio_segment.update!(upload_status: 'pending')
      end

      it 'returns error when segment is not available' do
        get :playback_url, params: { 
          id: project.id, 
          audioSegmentId: audio_segment.id 
        }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        
        expect(json_response['message']).to eq('Audio segment not available for playback')
        expect(json_response['code']).to eq('SEGMENT_NOT_AVAILABLE')
      end
    end

    context 'when audio segment does not exist' do
      it 'returns not found error' do
        get :playback_url, params: { 
          id: project.id, 
          audioSegmentId: 99999 
        }
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        
        expect(json_response['message']).to eq('Resource not found')
        expect(json_response['code']).to eq('NOT_FOUND')
      end
    end

    context 'when user does not own the project' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }
      let(:other_audio_segment) { create(:audio_segment, project: other_project) }

      it 'returns not found error' do
        get :playback_url, params: { 
          id: other_project.id, 
          audioSegmentId: other_audio_segment.id 
        }
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        
        expect(json_response['message']).to eq('Resource not found')
        expect(json_response['code']).to eq('NOT_FOUND')
      end
    end
  end

  describe '#upload_request' do
    let(:question) { create(:question, section: create(:section, chapter: create(:chapter, project: project))) }
    let(:valid_params) do
      {
        id: project.id,
        fileName: 'test_audio.m4a',
        mimeType: 'audio/mp4',
        recordedDurationSeconds: 30.5,
        questionId: question.id
      }
    end

    it 'creates audio segment and returns upload URL' do
      post :upload_request, params: valid_params

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('audioSegmentId')
      expect(json_response).to have_key('uploadUrl')
      expect(json_response).to have_key('expiresAt')
      
      audio_segment = AudioSegment.find(json_response['audioSegmentId'])
      expect(audio_segment.file_name).to eq('test_audio.m4a')
      expect(audio_segment.mime_type).to eq('audio/mp4')
      expect(audio_segment.duration_seconds).to eq(30)
      expect(audio_segment.upload_status).to eq('pending')
    end
  end

  describe '#upload_complete' do
    let(:audio_segment) { create(:audio_segment, project: project, upload_status: 'pending') }

    context 'when upload is successful' do
      it 'marks audio segment as successful and triggers transcription' do
        expect(TranscriptionService).to receive(:trigger_transcription_job).with(audio_segment.id)
        
        post :upload_complete, params: { 
          id: project.id,
          audioSegmentId: audio_segment.id,
          uploadStatus: 'success'
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['message']).to eq('Audio segment processing initiated')
        expect(json_response['status']).to eq('processing_started')
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('success')
      end
    end

    context 'when upload fails' do
      it 'marks audio segment as failed' do
        post :upload_complete, params: { 
          id: project.id,
          audioSegmentId: audio_segment.id,
          uploadStatus: 'failed',
          errorMessage: 'Upload failed due to network error'
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        
        expect(json_response['message']).to eq('Upload failed due to network error')
        expect(json_response['code']).to eq('UPLOAD_FAILED')
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('failed')
      end
    end
  end
end