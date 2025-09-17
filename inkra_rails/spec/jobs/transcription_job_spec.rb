require 'rails_helper'

RSpec.describe TranscriptionJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:audio_segment) { create(:audio_segment, project: project, upload_status: 'success') }

  describe '#perform' do
    context 'when transcription is successful' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_return({ success: true, text: 'Transcribed content' })
      end

      it 'calls TranscriptionService.process_transcription with the correct audio segment ID' do
        expect(TranscriptionService).to receive(:process_transcription).with(audio_segment.id)
        
        TranscriptionJob.perform_now(audio_segment.id)
      end

      it 'logs successful completion' do
        expect(Rails.logger).to receive(:info).with("Starting transcription job for audio segment #{audio_segment.id}")
        expect(Rails.logger).to receive(:info).with("Transcription job completed successfully for audio segment #{audio_segment.id}")
        
        TranscriptionJob.perform_now(audio_segment.id)
      end

      it 'returns the result from TranscriptionService' do
        result = TranscriptionJob.perform_now(audio_segment.id)
        
        expect(result[:success]).to be true
        expect(result[:text]).to eq('Transcribed content')
      end
    end

    context 'when transcription fails' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_return({ success: false, error: 'API error occurred' })
      end

      it 'logs the failure' do
        expect(Rails.logger).to receive(:info).with("Starting transcription job for audio segment #{audio_segment.id}")
        expect(Rails.logger).to receive(:error).with("Transcription job failed for audio segment #{audio_segment.id}: API error occurred")
        
        TranscriptionJob.perform_now(audio_segment.id)
      end

      it 'returns the error result from TranscriptionService' do
        result = TranscriptionJob.perform_now(audio_segment.id)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('API error occurred')
      end
    end

    context 'when an exception is raised' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error with backtrace and re-raises the exception' do
        expect(Rails.logger).to receive(:info).with("Starting transcription job for audio segment #{audio_segment.id}")
        expect(Rails.logger).to receive(:error).with("Transcription job error for audio segment #{audio_segment.id}: Unexpected error")
        expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace
        
        expect {
          TranscriptionJob.perform_now(audio_segment.id)
        }.to raise_error(StandardError, 'Unexpected error')
      end
    end

    context 'when audio segment does not exist' do
      it 'raises ActiveRecord::RecordNotFound and logs the error' do
        non_existent_id = 999999
        
        expect(Rails.logger).to receive(:info).with("Starting transcription job for audio segment #{non_existent_id}")
        expect(Rails.logger).to receive(:error).with("Transcription job error for audio segment #{non_existent_id}: Couldn't find AudioSegment with 'id'=#{non_existent_id}")
        expect(Rails.logger).to receive(:error).with(kind_of(String)) # backtrace
        
        expect {
          TranscriptionJob.perform_now(non_existent_id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'job enqueuing' do
    it 'is enqueued on the default queue' do
      expect(TranscriptionJob.new.queue_name).to eq('default')
    end

    it 'can be enqueued with perform_later' do
      expect {
        TranscriptionJob.perform_later(audio_segment.id)
      }.to have_enqueued_job(TranscriptionJob).with(audio_segment.id).on_queue('default')
    end

    it 'can be enqueued with a delay' do
      expect {
        TranscriptionJob.set(wait: 5.minutes).perform_later(audio_segment.id)
      }.to have_enqueued_job(TranscriptionJob)
        .with(audio_segment.id)
        .on_queue('default')
        .at(5.minutes.from_now)
    end
  end

  describe 'job retry behavior' do
    context 'when a retryable error occurs' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_raise(Net::TimeoutError, 'Request timeout')
      end

      it 'allows the job to be retried' do
        expect {
          TranscriptionJob.perform_now(audio_segment.id)
        }.to raise_error(Net::TimeoutError)
        
        # ActiveJob should allow this job to be retried based on default retry settings
      end
    end

    context 'when a non-retryable error occurs' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_raise(ActiveRecord::RecordNotFound, 'Record not found')
      end

      it 'raises the error without retrying' do
        expect {
          TranscriptionJob.perform_now(audio_segment.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'integration with TranscriptionService' do
    it 'processes the full transcription workflow' do
      # Mock the TranscriptionService to simulate realistic behavior
      allow(TranscriptionService).to receive(:process_transcription).with(audio_segment.id) do |id|
        segment = AudioSegment.find(id)
        segment.update!(upload_status: 'transcribed', transcription_text: 'Mocked transcription text')
        { success: true, text: 'Mocked transcription text' }
      end

      result = TranscriptionJob.perform_now(audio_segment.id)

      expect(result[:success]).to be true
      expect(result[:text]).to eq('Mocked transcription text')
      
      audio_segment.reload
      expect(audio_segment.upload_status).to eq('transcribed')
      expect(audio_segment.transcription_text).to eq('Mocked transcription text')
    end

    it 'handles project status updates correctly' do
      # Mock a scenario where this is the last segment to be transcribed
      allow(TranscriptionService).to receive(:process_transcription).with(audio_segment.id) do |id|
        segment = AudioSegment.find(id)
        project = segment.project
        
        # Simulate the service updating project status
        project.update!(status: 'transcribing')
        segment.update!(upload_status: 'transcribed', transcription_text: 'Transcribed text')
        
        { success: true, text: 'Transcribed text' }
      end

      TranscriptionJob.perform_now(audio_segment.id)

      project.reload
      expect(project.status).to eq('transcribing')
    end
  end

  describe 'error handling scenarios' do
    context 'when database connection is lost' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_raise(ActiveRecord::ConnectionTimeoutError, 'Database connection lost')
      end

      it 'logs the database error and re-raises for retry' do
        expect(Rails.logger).to receive(:error).with(/Database connection lost/)
        
        expect {
          TranscriptionJob.perform_now(audio_segment.id)
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end
    end

    context 'when external API is unavailable' do
      before do
        allow(TranscriptionService).to receive(:process_transcription)
          .and_return({ success: false, error: 'Service temporarily unavailable' })
      end

      it 'handles service unavailability gracefully' do
        result = TranscriptionJob.perform_now(audio_segment.id)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Service temporarily unavailable')
      end
    end
  end

  describe 'performance considerations' do
    it 'completes within reasonable time for normal audio segments' do
      allow(TranscriptionService).to receive(:process_transcription)
        .and_return({ success: true, text: 'Quick transcription' })
      
      start_time = Time.current
      TranscriptionJob.perform_now(audio_segment.id)
      end_time = Time.current
      
      # Job should complete quickly when mocked (under 1 second)
      expect(end_time - start_time).to be < 1.second
    end

    it 'handles large audio segments appropriately' do
      large_audio_segment = create(:audio_segment, 
                                   project: project, 
                                   upload_status: 'success',
                                   duration_seconds: 3600) # 1 hour
      
      allow(TranscriptionService).to receive(:process_transcription)
        .and_return({ success: true, text: 'Long transcription content' })
      
      result = TranscriptionJob.perform_now(large_audio_segment.id)
      
      expect(result[:success]).to be true
    end
  end
end