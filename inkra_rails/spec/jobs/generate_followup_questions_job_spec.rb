require 'rails_helper'

RSpec.describe GenerateFollowupQuestionsJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project_with_outline, user: user) }
  let(:chapter) { project.chapters.first }
  let(:section) { chapter.sections.first }
  let(:question) { section.questions.first }
  let(:audio_segment) do
    create(:audio_segment, 
           project: project,
           question: question,
           transcription_text: 'I think artificial intelligence will revolutionize healthcare by enabling early disease detection.',
           upload_status: 'transcribed')
  end

  before do
    # Mock InterviewQuestionService to avoid external API calls
    allow_any_instance_of(InterviewQuestionService).to receive(:generate_followup_questions)
      .and_return([
        { text: 'Can you elaborate on how AI would specifically help with early detection?' },
        { text: 'What challenges do you foresee in implementing AI in healthcare settings?' }
      ])
  end

  describe '#perform' do
    context 'when audio segment exists with question and transcription' do
      it 'generates and persists follow-up questions successfully' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.to change(Question, :count).by(2)

        # Verify the created questions
        follow_up_questions = question.follow_up_questions
        expect(follow_up_questions.count).to eq(2)
        
        expect(follow_up_questions.first.text).to eq('Can you elaborate on how AI would specifically help with early detection?')
        expect(follow_up_questions.second.text).to eq('What challenges do you foresee in implementing AI in healthcare settings?')
        
        # Verify follow-up questions are properly linked
        follow_up_questions.each do |fq|
          expect(fq.parent_question_id).to eq(question.id)
          expect(fq.is_follow_up).to be true
          expect(fq.section_id).to eq(question.section_id)
        end
      end

      it 'calls InterviewQuestionService with correct parameters' do
        service_instance = instance_double(InterviewQuestionService)
        allow(InterviewQuestionService).to receive(:new).and_return(service_instance)
        
        expect(service_instance).to receive(:generate_followup_questions).with(
          original_question_text: question.text,
          user_answer: audio_segment.transcription_text
        ).and_return([
          { text: 'Follow-up question 1' },
          { text: 'Follow-up question 2' }
        ])

        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
      end

      it 'assigns correct order numbers to follow-up questions' do
        # Create some existing questions in the section
        create(:question, section: section, order: 10)
        create(:question, section: section, order: 15)
        
        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)

        follow_up_questions = question.follow_up_questions.order(:order)
        
        # Follow-up questions should be ordered after the highest existing order (15)
        expect(follow_up_questions.first.order).to eq(16)
        expect(follow_up_questions.second.order).to eq(17)
      end

      it 'handles multiple sets of follow-up questions for the same parent' do
        # Generate first set of follow-ups
        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        
        # Create another audio segment for the same question
        audio_segment2 = create(:audio_segment,
                                project: project,
                                question: question,
                                transcription_text: 'Additional response about AI applications.',
                                upload_status: 'transcribed')
        
        # Mock service to return different questions
        allow_any_instance_of(InterviewQuestionService).to receive(:generate_followup_questions)
          .and_return([
            { text: 'What specific AI technologies are you most excited about?' }
          ])
        
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment2.id)
        }.to change(Question, :count).by(1)
        
        # Verify all follow-ups are linked to the same parent
        expect(question.follow_up_questions.count).to eq(3)
      end

      it 'logs job execution steps' do
        expect(Rails.logger).to receive(:info).with(/GenerateFollowupQuestionsJob: Starting with audio_segment_id/)
        expect(Rails.logger).to receive(:info).with(/Found audio_segment/)
        expect(Rails.logger).to receive(:info).with(/Generating followup questions for question/)
        expect(Rails.logger).to receive(:info).with(/Generated questions data/)
        expect(Rails.logger).to receive(:info).with(/Persisted .* new questions/)
        expect(Rails.logger).to receive(:info).with(/Follow-up questions saved for project/)
        
        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
      end
    end

    context 'when audio segment does not exist' do
      it 'logs warning and returns without error' do
        non_existent_id = 999999
        
        expect(Rails.logger).to receive(:info).with(/GenerateFollowupQuestionsJob: Starting with audio_segment_id/)
        expect(Rails.logger).to receive(:warn).with(/AudioSegment with id .* not found, skipping job/)
        
        expect {
          GenerateFollowupQuestionsJob.perform_now(non_existent_id)
        }.not_to change(Question, :count)
      end
    end

    context 'when audio segment has no question' do
      it 'returns early without generating questions' do
        audio_segment_without_question = create(:audio_segment,
                                                project: project,
                                                question: nil,
                                                transcription_text: 'Some transcription',
                                                upload_status: 'transcribed')
        
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment_without_question.id)
        }.not_to change(Question, :count)
      end
    end

    context 'when audio segment has no transcription' do
      it 'returns early without generating questions' do
        audio_segment_without_transcription = create(:audio_segment,
                                                     project: project,
                                                     question: question,
                                                     transcription_text: nil,
                                                     upload_status: 'uploaded')
        
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment_without_transcription.id)
        }.not_to change(Question, :count)
      end
    end

    context 'when InterviewQuestionService returns empty results' do
      before do
        allow_any_instance_of(InterviewQuestionService).to receive(:generate_followup_questions)
          .and_return([])
      end

      it 'does not create any questions' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.not_to change(Question, :count)
      end
    end

    context 'when InterviewQuestionService returns nil' do
      before do
        allow_any_instance_of(InterviewQuestionService).to receive(:generate_followup_questions)
          .and_return(nil)
      end

      it 'does not create any questions' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.not_to change(Question, :count)
      end
    end

    context 'when database transaction fails' do
      before do
        allow_any_instance_of(Question).to receive(:follow_up_questions).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises the error and rolls back any partial changes' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.to raise_error(ActiveRecord::RecordInvalid)
        
        # Verify no questions were created despite the error
        expect(question.follow_up_questions.count).to eq(0)
      end
    end
  end

  describe 'job enqueuing' do
    it 'is enqueued on the default queue' do
      expect(GenerateFollowupQuestionsJob.new.queue_name).to eq('default')
    end

    it 'can be enqueued with perform_later' do
      expect {
        GenerateFollowupQuestionsJob.perform_later(audio_segment.id)
      }.to have_enqueued_job(GenerateFollowupQuestionsJob).with(audio_segment.id).on_queue('default')
    end

    it 'can be enqueued with a delay' do
      expect {
        GenerateFollowupQuestionsJob.set(wait: 2.minutes).perform_later(audio_segment.id)
      }.to have_enqueued_job(GenerateFollowupQuestionsJob)
        .with(audio_segment.id)
        .on_queue('default')
        .at(2.minutes.from_now)
    end
  end

  describe 'integration with TranscriptionJob workflow' do
    context 'when called after successful transcription' do
      it 'processes the transcription result and generates follow-ups' do
        # Simulate the workflow: audio uploaded -> transcribed -> follow-ups generated
        audio_segment.update!(upload_status: 'uploaded')
        
        # Simulate transcription completion
        audio_segment.update!(
          upload_status: 'transcribed',
          transcription_text: 'Machine learning can help doctors diagnose diseases faster and more accurately.'
        )
        
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.to change(Question, :count).by(2)
      end
    end
  end

  describe 'performance considerations' do
    it 'uses efficient database queries with eager loading' do
      # Test that the job doesn't cause N+1 query problems
      # by monitoring query count during execution
      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        query_count += 1 unless args.last[:sql].include?('SCHEMA')
      end
      
      GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
      
      # Should be efficient with eager loading - expect reasonable query count
      expect(query_count).to be <= 10  # Reasonable limit for this operation
    end

    it 'completes within reasonable time for typical transcriptions' do
      start_time = Time.current
      GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
      end_time = Time.current
      
      # Job should complete quickly when mocked (under 2 seconds)
      expect(end_time - start_time).to be < 2.seconds
    end
  end

  describe 'error recovery scenarios' do
    context 'when external service is unavailable' do
      before do
        allow_any_instance_of(InterviewQuestionService).to receive(:generate_followup_questions)
          .and_raise(Net::TimeoutError, 'Service unavailable')
      end

      it 'raises the error for retry handling' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.to raise_error(Net::TimeoutError)
      end
    end

    context 'when database connection is lost' do
      before do
        allow(AudioSegment).to receive(:includes).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'raises the error for retry handling' do
        expect {
          GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end
    end
  end

  describe 'follow-up question ordering' do
    context 'with complex section structure' do
      let!(:early_question) { create(:question, section: section, order: 1) }
      let!(:middle_question) { create(:question, section: section, order: 5) }
      let!(:late_question) { create(:question, section: section, order: 10) }
      
      it 'places follow-ups after the highest ordered question in section' do
        # Generate follow-ups for the middle question
        audio_segment.update!(question: middle_question)
        
        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        
        follow_ups = middle_question.follow_up_questions.order(:order)
        
        # Follow-ups should come after order 10 (the highest in section)
        expect(follow_ups.first.order).to eq(11)
        expect(follow_ups.second.order).to eq(12)
      end
    end

    context 'with existing follow-up questions' do
      before do
        # Create existing follow-up questions for the same parent
        create(:question, section: section, parent_question: question, order: 20, is_follow_up: true)
        create(:question, section: section, parent_question: question, order: 21, is_follow_up: true)
      end

      it 'continues the ordering sequence for new follow-ups' do
        GenerateFollowupQuestionsJob.perform_now(audio_segment.id)
        
        all_follow_ups = question.follow_up_questions.order(:order)
        new_follow_ups = all_follow_ups.last(2)
        
        # New follow-ups should continue the sequence
        expect(new_follow_ups.first.order).to be > 21
        expect(new_follow_ups.second.order).to be > new_follow_ups.first.order
      end
    end
  end
end
