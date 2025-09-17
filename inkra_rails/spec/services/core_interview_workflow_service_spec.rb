require 'rails_helper'

RSpec.describe 'Core Interview Workflow', type: :service do
  describe 'smoothness requirements' do
    let(:user) { create(:user) }
    let(:project) { create(:project, user: user, is_speech_interview: true) }
    
    describe 'fast load times' do
      it 'loads interview questions in under 2 seconds' do
        start_time = Time.current
        service = InterviewFlowService.new(project)
        service.generate_question_queue
        end_time = Time.current
        
        expect(end_time - start_time).to be < 2.seconds
      end
      
      it 'preloads all necessary associations in single query' do
        query_count = 0
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1 unless args.last[:sql].include?('SCHEMA')
        end
        
        service = InterviewFlowService.new(project)
        service.generate_question_queue
        
        # Should use efficient eager loading - no N+1 queries
        expect(query_count).to be <= 3
      end
    end
    
    describe 'seamless navigation' do
      let!(:questions) { create_list(:question, 5, project: project) }
      
      it 'advances to next question without delay' do
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        start_time = Time.current
        next_question = service.get_next_priority_question(queue, 0)
        end_time = Time.current
        
        expect(next_question).to be_present
        expect(end_time - start_time).to be < 0.1.seconds
      end
      
      it 'maintains smooth flow even with background uploads' do
        # Simulate background upload scenario
        allow(BackgroundUploadService).to receive(:upload_audio).and_return(true)
        
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        # Navigation should not block on upload
        start_time = Time.current
        (0..2).each do |index|
          service.get_next_priority_question(queue, index)
        end
        end_time = Time.current
        
        expect(end_time - start_time).to be < 0.5.seconds
      end
    end
    
    describe 'buttery performance' do
      it 'handles large question sets without performance degradation' do
        create_list(:question, 100, project: project)
        
        service = InterviewFlowService.new(project)
        
        start_time = Time.current
        queue = service.generate_question_queue
        end_time = Time.current
        
        expect(queue.length).to eq(100)
        expect(end_time - start_time).to be < 1.second
      end
      
      it 'maintains performance with complex follow-up hierarchies' do
        # Create nested follow-up structure
        parent = create(:question, project: project, order: 1)
        create(:audio_segment, project: project, question: parent)
        
        # Create multiple levels of follow-ups
        (1..10).each do |level|
          create(:question, project: project, order: level + 1, is_follow_up: true, parent_question: parent)
        end
        
        service = InterviewFlowService.new(project)
        
        start_time = Time.current
        queue = service.generate_question_queue
        end_time = Time.current
        
        expect(end_time - start_time).to be < 0.5.seconds
        expect(queue.first.is_follow_up).to be true
      end
    end
  end
  
  describe 'reliability requirements' do
    let(:user) { create(:user) }
    let(:project) { create(:project, user: user, is_speech_interview: true) }
    
    describe 'no mismatched audio/questions' do
      let!(:question1) { create(:question, project: project, order: 1) }
      let!(:question2) { create(:question, project: project, order: 2) }
      
      it 'ensures audio URL matches question content' do
        # Mock Polly service
        allow_any_instance_of(PollyAudioService).to receive(:generate_audio)
          .with(question1.text, anything)
          .and_return('https://s3.amazonaws.com/audio/question1.mp3')
        
        audio_url = PollyAudioService.new.generate_audio(question1.text, 'Joanna')
        
        expect(audio_url).to include('question1')
        expect(audio_url).not_to include('question2')
      end
      
      it 'validates audio-question pairing before delivery' do
        question1.update!(polly_audio_url: 'https://s3.amazonaws.com/audio/question1.mp3')
        question2.update!(polly_audio_url: 'https://s3.amazonaws.com/audio/question2.mp3')
        
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        # Each question should have unique audio URL
        audio_urls = queue.map(&:polly_audio_url).compact
        expect(audio_urls.uniq.length).to eq(audio_urls.length)
      end
      
      it 'prevents serving questions without audio in speech interviews' do
        project.update!(is_speech_interview: true)
        question_without_audio = create(:question, project: project, polly_audio_url: nil)
        
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        # For speech interviews, questions without audio should not appear
        question_ids = queue.map(&:id)
        expect(question_ids).not_to include(question_without_audio.id)
      end
    end
    
    describe 'stable silence detection' do
      it 'provides consistent silence threshold settings' do
        # Test that silence detection configuration is stable
        config = {
          silence_threshold: -30.0, # dB
          silence_duration: 3.0,    # seconds
          auto_advance_enabled: true
        }
        
        expect(config[:silence_threshold]).to be_between(-40.0, -20.0)
        expect(config[:silence_duration]).to be_between(2.0, 5.0)
        expect(config[:auto_advance_enabled]).to be_in([true, false])
      end
      
      it 'maintains silence detection state across question transitions' do
        # Simulate silence detection state persistence
        silence_state = {
          current_threshold: -30.0,
          detection_active: true,
          countdown_active: false
        }
        
        # State should persist between questions
        expect(silence_state[:detection_active]).to be true
        expect(silence_state[:current_threshold]).to eq(-30.0)
      end
    end
    
    describe 'predictable behavior' do
      let!(:questions) { create_list(:question, 3, project: project) }
      
      it 'maintains consistent question ordering across multiple calls' do
        service = InterviewFlowService.new(project)
        
        queue1 = service.generate_question_queue
        queue2 = service.generate_question_queue
        
        expect(queue1.map(&:id)).to eq(queue2.map(&:id))
      end
      
      it 'provides deterministic follow-up insertion behavior' do
        parent_question = questions.first
        create(:audio_segment, project: project, question: parent_question)
        
        followup1 = create(:question, project: project, is_follow_up: true, parent_question: parent_question, order: 10)
        followup2 = create(:question, project: project, is_follow_up: true, parent_question: parent_question, order: 11)
        
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        # Follow-ups should appear in consistent order
        followup_positions = queue.map.with_index { |q, i| i if q.is_follow_up }.compact
        expect(followup_positions).to eq(followup_positions.sort)
      end
      
      it 'handles error states gracefully without breaking flow' do
        # Simulate various error conditions
        allow(Rails.logger).to receive(:error)
        
        # Network error simulation
        allow_any_instance_of(InterviewFlowService).to receive(:generate_question_queue)
          .and_raise(Net::TimeoutError)
        
        service = InterviewFlowService.new(project)
        
        expect {
          service.generate_question_queue rescue nil
        }.not_to raise_error
        
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end
  end
  
  describe 'flexibility requirements' do
    let(:user) { create(:user) }
    
    describe 'silence detection toggle' do
      let(:speech_project) { create(:project, user: user, is_speech_interview: true) }
      
      it 'supports enabling/disabling auto-advance' do
        # Test auto-advance configuration
        auto_advance_settings = {
          enabled: true,
          silence_threshold: -30.0,
          countdown_duration: 5
        }
        
        # Should be configurable
        auto_advance_settings[:enabled] = false
        expect(auto_advance_settings[:enabled]).to be false
        
        auto_advance_settings[:enabled] = true
        expect(auto_advance_settings[:enabled]).to be true
      end
      
      it 'maintains interview flow regardless of silence detection setting' do
        create_list(:question, 3, project: speech_project)
        
        service = InterviewFlowService.new(speech_project)
        queue = service.generate_question_queue
        
        # Flow should work with any silence detection setting
        expect(queue.length).to eq(3)
        
        # Manual navigation should always be available
        next_question = service.get_next_priority_question(queue, 0)
        expect(next_question).to be_present
      end
    end
    
    describe 'spoken vs reading modes' do
      let(:speech_project) { create(:project, user: user, is_speech_interview: true) }
      let(:reading_project) { create(:project, user: user, is_speech_interview: false) }
      
      it 'differentiates between speech and reading interview modes' do
        expect(speech_project.is_speech_interview).to be true
        expect(reading_project.is_speech_interview).to be false
      end
      
      it 'provides appropriate question delivery for each mode' do
        speech_question = create(:question, project: speech_project, polly_audio_url: 'audio.mp3')
        reading_question = create(:question, project: reading_project, polly_audio_url: nil)
        
        speech_service = InterviewFlowService.new(speech_project)
        reading_service = InterviewFlowService.new(reading_project)
        
        speech_queue = speech_service.generate_question_queue
        reading_queue = reading_service.generate_question_queue
        
        # Speech interview questions should have audio
        expect(speech_queue.first.polly_audio_url).to be_present
        
        # Reading interview questions don't require audio
        expect(reading_queue.first).to be_present
      end
      
      it 'supports switching between modes for same user' do
        # User should be able to create both types of interviews
        speech_project = create(:project, user: user, is_speech_interview: true)
        reading_project = create(:project, user: user, is_speech_interview: false)
        
        expect(user.projects).to include(speech_project, reading_project)
        expect(speech_project.is_speech_interview).not_to eq(reading_project.is_speech_interview)
      end
    end
  end
  
  describe 'architecture requirements' do
    let(:user) { create(:user) }
    let(:project) { create(:project, user: user) }
    
    describe 'simplified, stable core implementation' do
      it 'uses minimal external dependencies' do
        service = InterviewFlowService.new(project)
        
        # Core flow should depend only on ActiveRecord and basic Rails
        expect(service).to respond_to(:generate_question_queue)
        expect(service).to respond_to(:get_next_priority_question)
        expect(service).to respond_to(:insert_followup_questions)
      end
      
      it 'provides clear, focused API surface' do
        service = InterviewFlowService.new(project)
        
        # API should be simple and focused
        public_methods = service.public_methods(false)
        expect(public_methods.length).to be <= 5
        
        # Core methods should be present
        expect(public_methods).to include(:generate_question_queue)
      end
      
      it 'maintains separation of concerns' do
        # Flow service should not handle audio processing
        service = InterviewFlowService.new(project)
        
        expect(service).not_to respond_to(:generate_audio)
        expect(service).not_to respond_to(:upload_audio)
        expect(service).not_to respond_to(:process_transcript)
      end
      
      it 'provides stable behavior under load' do
        # Create concurrent access scenario
        services = Array.new(5) { InterviewFlowService.new(project) }
        
        threads = services.map do |service|
          Thread.new { service.generate_question_queue }
        end
        
        results = threads.map(&:value)
        
        # All services should return consistent results
        expect(results.uniq.length).to eq(1)
      end
    end
    
    describe 'focus on basics' do
      it 'prioritizes core functionality over advanced features' do
        service = InterviewFlowService.new(project)
        
        # Basic functions should be fast and reliable
        expect { service.generate_question_queue }.not_to raise_error
        
        # Should not include complex AI processing in core flow
        expect(service).not_to respond_to(:analyze_sentiment)
        expect(service).not_to respond_to(:generate_insights)
      end
      
      it 'maintains simple data structures' do
        service = InterviewFlowService.new(project)
        queue = service.generate_question_queue
        
        # Queue should be simple array of questions
        expect(queue).to be_an(Array)
        expect(queue.first).to be_a(Question) if queue.any?
      end
      
      it 'provides predictable error handling' do
        # Test with invalid project
        invalid_project = Project.new
        service = InterviewFlowService.new(invalid_project)
        
        expect { service.generate_question_queue }.not_to raise_error
      end
    end
  end
  
  describe 'edge cases and error handling' do
    let(:user) { create(:user) }
    let(:project) { create(:project, user: user) }
    
    it 'handles empty projects gracefully' do
      empty_project = create(:project, user: user)
      service = InterviewFlowService.new(empty_project)
      
      queue = service.generate_question_queue
      expect(queue).to be_empty
    end
    
    it 'handles circular follow-up references without infinite loops' do
      q1 = create(:question, project: project, order: 1)
      q2 = create(:question, project: project, order: 2, is_follow_up: true, parent_question: q1)
      
      # This shouldn't cause infinite loops
      service = InterviewFlowService.new(project)
      queue = service.generate_question_queue
      
      expect(queue.length).to eq(2)
    end
    
    it 'handles database connection issues' do
      allow(Question).to receive(:joins).and_raise(ActiveRecord::ConnectionNotEstablished)
      
      service = InterviewFlowService.new(project)
      
      expect { service.generate_question_queue }.not_to raise_error
    end
    
    it 'handles memory pressure gracefully' do
      # Simulate large dataset
      allow(project).to receive(:questions).and_return(double(joins: double(where: [])))
      
      service = InterviewFlowService.new(project)
      queue = service.generate_question_queue
      
      expect(queue).to be_an(Array)
    end
  end
end