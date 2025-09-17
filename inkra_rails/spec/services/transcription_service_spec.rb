require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TranscriptionService, type: :service do
  let(:project) { create(:project, status: 'recording_in_progress') }
  let(:audio_segment) { create(:audio_segment, project: project, upload_status: 'success') }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    WebMock.allow_net_connect!
  end

  describe '.trigger_transcription_job' do
    it 'enqueues a transcription job' do
      expect(TranscriptionJob).to receive(:perform_later).with(audio_segment.id)
      
      described_class.trigger_transcription_job(audio_segment.id)
    end
  end

  describe '.process_transcription' do
    context 'when OpenAI API is configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return('test-api-key')
        allow(described_class).to receive(:download_audio_from_s3).and_return('mock_audio_data')
      end

      context 'with successful API response' do
        before do
          stub_request(:post, TranscriptionService::WHISPER_API_URL)
            .to_return(
              status: 200,
              body: { text: 'This is the transcribed text from the audio.' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'successfully transcribes audio and updates segment' do
          result = described_class.process_transcription(audio_segment.id)

          expect(result[:success]).to be true
          expect(result[:text]).to eq('This is the transcribed text from the audio.')
          
          audio_segment.reload
          expect(audio_segment.upload_status).to eq('transcribed')
          expect(audio_segment.transcription_text).to eq('This is the transcribed text from the audio.')
        end

        it 'updates project status to transcribing' do
          described_class.process_transcription(audio_segment.id)
          
          project.reload
          expect(project.status).to eq('transcribing')
        end

        it 'triggers transcript processing when all segments are transcribed' do
          # Create another segment that's already transcribed
          create(:audio_segment, project: project, upload_status: 'transcribed')
          
          expect(TranscriptProcessorService).to receive(:process_transcript).with(project.id)
          
          described_class.process_transcription(audio_segment.id)
        end
      end

      context 'with failed API response' do
        before do
          stub_request(:post, TranscriptionService::WHISPER_API_URL)
            .to_return(
              status: 400,
              body: { error: { message: 'Invalid file format' } }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'handles API errors gracefully' do
          result = described_class.process_transcription(audio_segment.id)

          expect(result[:success]).to be false
          expect(result[:error]).to eq('Invalid file format')
          
          audio_segment.reload
          expect(audio_segment.upload_status).to eq('transcription_failed')
        end

        it 'updates project status to failed when no successful segments remain' do
          described_class.process_transcription(audio_segment.id)
          
          project.reload
          expect(project.status).to eq('failed')
        end
      end

      context 'when S3 download fails' do
        before do
          allow(described_class).to receive(:download_audio_from_s3).and_return(nil)
        end

        it 'falls back to mock transcription' do
          allow(described_class).to receive(:generate_mock_transcription).and_return({
            success: true,
            text: 'Mock transcription text'
          })

          result = described_class.process_transcription(audio_segment.id)

          expect(result[:success]).to be true
          expect(result[:text]).to eq('Mock transcription text')
        end
      end
    end

    context 'when OpenAI API is not configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'falls back to mock transcription' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be true
        expect(result[:text]).to be_present
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('transcribed')
        expect(audio_segment.transcription_text).to be_present
      end
    end

    context 'when audio segment not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect { described_class.process_transcription(99999) }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when database update fails' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:aws, :s3_bucket).and_return(nil)
        allow(audio_segment).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        allow(AudioSegment).to receive(:find).and_return(audio_segment)
      end

      it 'handles database errors gracefully' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe '.download_audio_from_s3' do
    let(:mock_s3_client) { instance_double(Aws::S3::Client) }
    let(:mock_response) { double('response', body: double('body', read: 'audio_data')) }

    before do
      allow(Rails.application.credentials).to receive(:dig).with(:aws, :s3_bucket).and_return('test-bucket')
      allow(Rails.application.credentials).to receive(:dig).with(:aws, :region).and_return('us-east-1')
      allow(Rails.application.credentials).to receive(:dig).with(:aws, :access_key_id).and_return('test-key')
      allow(Rails.application.credentials).to receive(:dig).with(:aws, :secret_access_key).and_return('test-secret')
      allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
    end

    context 'with valid S3 configuration' do
      it 'successfully downloads audio data' do
        allow(mock_s3_client).to receive(:get_object).and_return(mock_response)

        result = described_class.send(:download_audio_from_s3, audio_segment)

        expect(result).to eq('audio_data')
        expect(mock_s3_client).to have_received(:get_object).with(
          bucket: 'test-bucket',
          key: "audio_segments/#{audio_segment.id}/#{audio_segment.file_name}"
        )
      end

      it 'handles S3 errors gracefully' do
        allow(mock_s3_client).to receive(:get_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil))

        result = described_class.send(:download_audio_from_s3, audio_segment)

        expect(result).to be_nil
      end
    end

    context 'without S3 configuration' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:aws, :s3_bucket).and_return(nil)
        allow(ENV).to receive(:[]).with('AWS_S3_BUCKET').and_return(nil)
      end

      it 'returns nil when bucket is not configured' do
        result = described_class.send(:download_audio_from_s3, audio_segment)

        expect(result).to be_nil
      end
    end
  end

  describe '.transcribe_with_whisper' do
    let(:audio_data) { 'binary_audio_data' }
    let(:api_key) { 'test-api-key' }

    context 'with successful API response' do
      before do
        stub_request(:post, TranscriptionService::WHISPER_API_URL)
          .to_return(
            status: 200,
            body: { text: 'Transcribed audio content' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'sends correct request to Whisper API' do
        result = described_class.send(:transcribe_with_whisper, audio_data, audio_segment, api_key)

        expect(result[:success]).to be true
        expect(result[:text]).to eq('Transcribed audio content')

        expect(WebMock).to have_requested(:post, TranscriptionService::WHISPER_API_URL)
          .with(headers: { 'Authorization' => 'Bearer test-api-key' })
      end
    end

    context 'with API error response' do
      before do
        stub_request(:post, TranscriptionService::WHISPER_API_URL)
          .to_return(
            status: 429,
            body: { error: { message: 'Rate limit exceeded' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles API errors' do
        result = described_class.send(:transcribe_with_whisper, audio_data, audio_segment, api_key)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Rate limit exceeded')
      end
    end

    context 'with malformed API response' do
      before do
        stub_request(:post, TranscriptionService::WHISPER_API_URL)
          .to_return(
            status: 500,
            body: 'Internal Server Error',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'handles malformed responses' do
        result = described_class.send(:transcribe_with_whisper, audio_data, audio_segment, api_key)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('HTTP 500: Internal Server Error')
      end
    end

    context 'with network timeout' do
      before do
        stub_request(:post, TranscriptionService::WHISPER_API_URL)
          .to_timeout
      end

      it 'handles network timeouts' do
        expect {
          described_class.send(:transcribe_with_whisper, audio_data, audio_segment, api_key)
        }.to raise_error(Net::OpenTimeout)
      end
    end
  end

  describe '.generate_mock_transcription' do
    let(:question) { create(:question, text: 'What is your name?') }
    let(:audio_segment_with_question) { create(:audio_segment, question: question) }

    it 'generates mock transcription data' do
      result = described_class.send(:generate_mock_transcription, audio_segment)

      expect(result[:success]).to be true
      expect(result[:text]).to be_present
      expect(result[:confidence]).to be_between(0.85, 0.98)
      expect(result[:language]).to eq('en-US')
    end

    it 'generates contextual responses for questions' do
      result = described_class.send(:generate_mock_transcription, audio_segment_with_question)

      expect(result[:text]).to be_present
      # Should generate a name-related response
      expect(result[:text]).to match(/name|I'm|Hi,/)
    end
  end

  describe '.generate_contextual_response' do
    it 'generates appropriate responses for name questions' do
      response = described_class.send(:generate_contextual_response, 'What is your name?')
      expect(response).to match(/name|I'm|Hi,/)
    end

    it 'generates appropriate responses for background questions' do
      response = described_class.send(:generate_contextual_response, 'Tell me about your background')
      expect(response).to match(/experience|years|background|career/)
    end

    it 'generates appropriate responses for challenge questions' do
      response = described_class.send(:generate_contextual_response, 'What was your biggest challenge?')
      expect(response).to match(/challenge|difficult|problem/)
    end

    it 'generates appropriate responses for goal questions' do
      response = described_class.send(:generate_contextual_response, 'What are your goals?')
      expect(response).to match(/goal|future|plan/)
    end

    it 'generates appropriate responses for learning questions' do
      response = described_class.send(:generate_contextual_response, 'What advice would you give?')
      expect(response).to match(/learn|advice|important/)
    end

    it 'generates generic responses for other questions' do
      response = described_class.send(:generate_contextual_response, 'Random question')
      expect(response).to be_present
      expect(response.length).to be > 10
    end
  end

  describe '.all_segments_transcribed?' do
    let(:project_with_segments) { create(:project) }

    context 'when all segments are transcribed' do
      before do
        create(:audio_segment, project: project_with_segments, upload_status: 'transcribed')
        create(:audio_segment, project: project_with_segments, upload_status: 'transcribed')
      end

      it 'returns true' do
        result = described_class.send(:all_segments_transcribed?, project_with_segments)
        expect(result).to be true
      end
    end

    context 'when some segments are not transcribed' do
      before do
        create(:audio_segment, project: project_with_segments, upload_status: 'transcribed')
        create(:audio_segment, project: project_with_segments, upload_status: 'success')
      end

      it 'returns false' do
        result = described_class.send(:all_segments_transcribed?, project_with_segments)
        expect(result).to be false
      end
    end

    context 'when project has no segments' do
      it 'returns true' do
        result = described_class.send(:all_segments_transcribed?, project_with_segments)
        expect(result).to be true
      end
    end

    context 'when project has failed segments' do
      before do
        create(:audio_segment, project: project_with_segments, upload_status: 'transcribed')
        create(:audio_segment, project: project_with_segments, upload_status: 'transcription_failed')
      end

      it 'returns false' do
        result = described_class.send(:all_segments_transcribed?, project_with_segments)
        expect(result).to be false
      end
    end
  end

  describe 'error scenarios' do
    context 'when project update fails' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:aws, :s3_bucket).and_return(nil)
        allow(project).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        allow(audio_segment).to receive(:project).and_return(project)
      end

      it 'handles project update errors' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end

    context 'when TranscriptProcessorService fails' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:aws, :s3_bucket).and_return(nil)
        allow(TranscriptProcessorService).to receive(:process_transcript).and_raise(StandardError, 'Processor failed')
      end

      it 'does not affect transcription success' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be true
        
        audio_segment.reload
        expect(audio_segment.upload_status).to eq('transcribed')
      end
    end

    context 'with development environment fallback' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return('test-key')
        allow(described_class).to receive(:download_audio_from_s3).and_raise(StandardError, 'S3 error')
      end

      it 'falls back to mock transcription in development' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be true
        expect(result[:text]).to be_present
      end
    end

    context 'with production environment error handling' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return('test-key')
        allow(described_class).to receive(:download_audio_from_s3).and_raise(StandardError, 'S3 error')
      end

      it 'returns error in production' do
        result = described_class.process_transcription(audio_segment.id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('S3 error')
      end
    end
  end
end