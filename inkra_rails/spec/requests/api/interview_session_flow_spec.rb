require 'rails_helper'

RSpec.describe 'API Interview Session Flow', type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{generate_jwt_token(user)}" } }
  
  describe 'Core Interview Flow API Requirements' do
    describe 'interview type selection flow' do
      context 'spoken interview path' do
        let(:voice_params) do
          {
            topic: 'Building a successful startup',
            is_speech_interview: true,
            voice_id: 'Joanna',
            speech_rate: 100
          }
        end
        
        it 'creates spoken interview with voice selection' do
          post '/api/projects', params: voice_params, headers: auth_headers
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          project = Project.find(json_response['id'])
          
          expect(project.is_speech_interview).to be true
          expect(project.voice_id).to eq('Joanna')
          expect(project.speech_rate).to eq(100)
        end
        
        it 'shows full-screen loading during setup' do
          post '/api/projects', params: voice_params, headers: auth_headers
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('initializing')
          expect(json_response['message']).to include('Setting up voice interview')
        end
        
        it 'requires voice selection for spoken interviews' do
          invalid_params = voice_params.except(:voice_id)
          
          post '/api/projects', params: invalid_params, headers: auth_headers
          
          expect(response).to have_http_status(:unprocessable_entity)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('voice')
        end
      end
      
      context 'reading interview path' do
        let(:reading_params) do
          {
            topic: 'My career journey',
            is_speech_interview: false
          }
        end
        
        it 'creates reading interview without voice setup' do
          post '/api/projects', params: reading_params, headers: auth_headers
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          project = Project.find(json_response['id'])
          
          expect(project.is_speech_interview).to be false
          expect(project.voice_id).to be_nil
        end
        
        it 'skips audio generation for reading interviews' do
          post '/api/projects', params: reading_params, headers: auth_headers
          
          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('outline_ready')
          expect(json_response['message']).not_to include('audio')
        end
      end
    end
    
    describe 'during interview controls' do
      let(:project) { create(:project, user: user, is_speech_interview: true) }
      let!(:questions) { create_list(:question, 5, project: project) }
      
      describe 'next question control' do
        it 'saves and uploads current audio, moves to next question' do
          # Mock audio upload
          allow(BackgroundUploadService).to receive(:upload_audio).and_return(true)
          
          post "/api/projects/#{project.id}/next_question", 
               params: { audio_data: 'base64_audio_data' },
               headers: auth_headers
          
          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response['action']).to eq('next_question')
          expect(json_response['audio_uploaded']).to be true
          expect(json_response['current_question_index']).to be > 0
        end
        
        it 'handles background upload without blocking' do
          # Simulate slow upload
          allow(BackgroundUploadService).to receive(:upload_audio) do
            sleep(0.1) # Simulate network delay
            true
          end
          
          start_time = Time.current
          post "/api/projects/#{project.id}/next_question", 
               params: { audio_data: 'base64_audio_data' },
               headers: auth_headers
          end_time = Time.current
          
          expect(response).to have_http_status(:ok)
          # Should not block on upload
          expect(end_time - start_time).to be < 0.5.seconds
        end
      end
      
      describe 'skip question control' do
        it 'discards current audio, moves to next question' do
          post "/api/projects/#{project.id}/skip_question", headers: auth_headers
          
          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response['action']).to eq('skip_question')
          expect(json_response['audio_discarded']).to be true
          expect(json_response['current_question_index']).to be > 0
        end
        
        it 'marks question as skipped in database' do
          current_question = questions.first
          
          post "/api/projects/#{project.id}/skip_question", 
               params: { question_id: current_question.id },
               headers: auth_headers
          
          expect(response).to have_http_status(:ok)
          
          current_question.reload
          expect(current_question.skipped).to be true
        end
      end
      
      describe 'end session control' do
        it 'returns to project overview screen' do
          post "/api/projects/#{project.id}/end_session", headers: auth_headers
          
          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response['action']).to eq('end_session')
          expect(json_response['redirect_to']).to eq('project_overview')
          expect(json_response['session_ended']).to be true
        end
        
        it 'saves current progress before ending' do
          post "/api/projects/#{project.id}/end_session",
               params: { 
                 current_question_index: 2,
                 audio_data: 'final_audio_data'
               },
               headers: auth_headers
          
          expect(response).to have_http_status(:ok)
          
          project.reload
          expect(project.last_accessed_at).to be_within(1.minute).of(Time.current)
        end
      end
    end
    
    describe 'silence detection functionality' do
      let(:project) { create(:project, user: user, is_speech_interview: true) }
      let!(:questions) { create_list(:question, 3, project: project) }
      
      it 'detects prolonged silence and auto-advances' do
        post "/api/projects/#{project.id}/silence_detected",
             params: { 
               silence_duration: 5.0,
               auto_advance_enabled: true 
             },
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['action']).to eq('auto_advance')
        expect(json_response['reason']).to eq('silence_detected')
        expect(json_response['next_question']).to be_present
      end
      
      it 'respects silence detection disable option' do
        post "/api/projects/#{project.id}/silence_detected",
             params: { 
               silence_duration: 5.0,
               auto_advance_enabled: false 
             },
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['action']).to eq('manual_navigation_required')
        expect(json_response['silence_detected']).to be true
        expect(json_response['auto_advance_disabled']).to be true
      end
      
      it 'configures silence threshold settings' do
        get "/api/projects/#{project.id}/silence_settings", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['silence_threshold']).to be_present
        expect(json_response['silence_duration']).to be_present
        expect(json_response['auto_advance_enabled']).to be_in([true, false])
      end
    end
    
    describe 'non-blocking networking' do
      let(:project) { create(:project, user: user, is_speech_interview: true) }
      let!(:questions) { create_list(:question, 3, project: project) }
      
      it 'uploads audio in background without blocking UI' do
        # Mock slow network
        allow(BackgroundUploadService).to receive(:upload_audio) do
          sleep(2) # Simulate 2 second upload
          true
        end
        
        start_time = Time.current
        post "/api/projects/#{project.id}/upload_audio",
             params: { audio_data: 'large_audio_file' },
             headers: auth_headers
        end_time = Time.current
        
        expect(response).to have_http_status(:accepted) # Accepted for background processing
        expect(end_time - start_time).to be < 1.second # Should not block
        
        json_response = JSON.parse(response.body)
        expect(json_response['upload_status']).to eq('queued')
        expect(json_response['blocking']).to be false
      end
      
      it 'provides upload progress without freezing' do
        # Mock upload progress tracking
        upload_id = SecureRandom.uuid
        
        get "/api/projects/#{project.id}/upload_progress/#{upload_id}", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('progress_percentage')
        expect(json_response).to have_key('estimated_completion')
        expect(json_response['blocking_ui']).to be false
      end
      
      it 'handles network failures gracefully' do
        # Mock network failure
        allow(BackgroundUploadService).to receive(:upload_audio).and_raise(Net::TimeoutError)
        
        post "/api/projects/#{project.id}/upload_audio",
             params: { audio_data: 'audio_data' },
             headers: auth_headers
        
        expect(response).to have_http_status(:service_unavailable)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('network')
        expect(json_response['retry_available']).to be true
        expect(json_response['blocking']).to be false
      end
    end
    
    describe 'follow-up questions integration' do
      let(:project) { create(:project, user: user) }
      let!(:answered_question) { create(:question, project: project, order: 1) }
      let!(:audio_segment) { create(:audio_segment, project: project, question: answered_question) }
      
      it 'sends audio to backend (Gemini) after question is answered' do
        # Mock Gemini API call
        allow(GenerateFollowupQuestionsJob).to receive(:perform_later).and_return(true)
        
        post "/api/projects/#{project.id}/process_answer",
             params: { 
               question_id: answered_question.id,
               audio_segment_id: audio_segment.id
             },
             headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['gemini_processing']).to be true
        expect(json_response['followup_generation_queued']).to be true
        
        expect(GenerateFollowupQuestionsJob).to have_received(:perform_later)
      end
      
      it 'retrieves and inserts follow-up questions into interview' do
        # Create follow-up questions
        followup1 = create(:question, project: project, is_follow_up: true, parent_question: answered_question, order: 10)
        followup2 = create(:question, project: project, is_follow_up: true, parent_question: answered_question, order: 11)
        
        get "/api/projects/#{project.id}/available_questions", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        # Follow-ups should appear first (urgent)
        first_question = questions.first
        expect(first_question['is_follow_up']).to be true
        expect(first_question['parent_question_id']).to eq(answered_question.id)
      end
      
      it 'ensures correct audio matching for follow-up questions' do
        followup = create(:question, 
                         project: project, 
                         is_follow_up: true, 
                         parent_question: answered_question,
                         polly_audio_url: 'https://s3.amazonaws.com/followup_audio.mp3')
        
        get "/api/projects/#{project.id}/available_questions", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        followup_question = json_response['questions'].find { |q| q['id'] == followup.id }
        
        expect(followup_question['polly_audio_url']).to eq(followup.polly_audio_url)
        expect(followup_question['text']).to eq(followup.text)
        
        # Audio URL should be unique and match question content
        expect(followup_question['polly_audio_url']).to include('followup')
      end
    end
    
    describe 'project overview screen functionality' do
      let(:project) { create(:project, user: user) }
      let!(:completed_questions) { create_list(:question, 3, project: project) }
      let!(:audio_segments) { completed_questions.map { |q| create(:audio_segment, project: project, question: q) } }
      
      it 'provides multiple interaction options after session end' do
        get "/api/projects/#{project.id}/overview", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['interactions']).to include('resume_interview')
        expect(json_response['interactions']).to include('view_transcript')
        expect(json_response['interactions']).to include('export_responses')
        expect(json_response['interactions']).to include('edit_outline')
      end
      
      it 'shows interview completion status' do
        get "/api/projects/#{project.id}/overview", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['completion_status']).to be_present
        expect(json_response['total_questions']).to eq(completed_questions.length)
        expect(json_response['answered_questions']).to eq(audio_segments.length)
        expect(json_response['progress_percentage']).to be_between(0, 100)
      end
      
      it 'allows resuming from where user left off' do
        post "/api/projects/#{project.id}/resume_interview", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['resume_available']).to be true
        expect(json_response['current_question_index']).to be >= 0
        expect(json_response['remaining_questions']).to be_present
      end
    end
  end
  
  describe 'performance and reliability requirements' do
    let(:project) { create(:project, user: user) }
    
    describe 'fast load times' do
      it 'loads available questions in under 2 seconds' do
        create_list(:question, 20, project: project)
        
        start_time = Time.current
        get "/api/projects/#{project.id}/available_questions", headers: auth_headers
        end_time = Time.current
        
        expect(response).to have_http_status(:ok)
        expect(end_time - start_time).to be < 2.seconds
      end
    end
    
    describe 'seamless navigation' do
      let!(:questions) { create_list(:question, 10, project: project) }
      
      it 'provides next question without delay' do
        start_time = Time.current
        post "/api/projects/#{project.id}/next_question", headers: auth_headers
        end_time = Time.current
        
        expect(response).to have_http_status(:ok)
        expect(end_time - start_time).to be < 0.5.seconds
      end
    end
    
    describe 'no mismatched audio/questions' do
      let!(:question) { create(:question, project: project, polly_audio_url: 'https://s3.amazonaws.com/question_audio.mp3') }
      
      it 'validates audio-question pairing' do
        get "/api/projects/#{project.id}/available_questions", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        returned_question = json_response['questions'].first
        
        expect(returned_question['id']).to eq(question.id)
        expect(returned_question['polly_audio_url']).to eq(question.polly_audio_url)
        expect(returned_question['text']).to eq(question.text)
      end
    end
  end
  
  describe 'error handling and edge cases' do
    let(:project) { create(:project, user: user) }
    
    it 'handles empty project gracefully' do
      empty_project = create(:project, user: user)
      
      get "/api/projects/#{empty_project.id}/available_questions", headers: auth_headers
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['questions']).to be_empty
      expect(json_response['message']).to include('no questions')
    end
    
    it 'handles network timeouts gracefully' do
      # Mock timeout
      allow_any_instance_of(InterviewFlowService).to receive(:generate_question_queue)
        .and_raise(Net::TimeoutError)
      
      get "/api/projects/#{project.id}/available_questions", headers: auth_headers
      
      expect(response).to have_http_status(:service_unavailable)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('timeout')
      expect(json_response['retry_after']).to be_present
    end
    
    it 'maintains session state during errors' do
      # Simulate error during question transition
      allow_any_instance_of(InterviewFlowService).to receive(:get_next_priority_question)
        .and_raise(StandardError.new('Database error'))
      
      post "/api/projects/#{project.id}/next_question", headers: auth_headers
      
      expect(response).to have_http_status(:internal_server_error)
      
      json_response = JSON.parse(response.body)
      expect(json_response['session_preserved']).to be true
      expect(json_response['recovery_available']).to be true
    end
  end
  
  private
  
  def generate_jwt_token(user)
    JwtService.encode(user_id: user.id)
  end
end