require 'rails_helper'

RSpec.describe AudioSegment, type: :model do
  subject(:audio_segment) { build(:audio_segment) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:file_name) }
    it { is_expected.to validate_presence_of(:mime_type) }
    it { is_expected.to validate_presence_of(:upload_status) }
    it { is_expected.to validate_presence_of(:duration_seconds) }
    it { is_expected.to validate_numericality_of(:duration_seconds).is_greater_than(0) }
    
    it { is_expected.to validate_inclusion_of(:upload_status).in_array(%w[
      pending 
      uploading 
      success 
      failed 
      transcribed 
      transcription_failed
    ]) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:question).optional }
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:file_name).of_type(:string) }
    it { is_expected.to have_db_column(:mime_type).of_type(:string) }
    it { is_expected.to have_db_column(:duration_seconds).of_type(:integer) }
    it { is_expected.to have_db_column(:upload_status).of_type(:string) }
    it { is_expected.to have_db_column(:s3_url).of_type(:string) }
    it { is_expected.to have_db_column(:transcription_text).of_type(:text) }
  end

  describe 'scopes' do
    let(:project) { create(:project) }
    
    before do
      create(:audio_segment, project: project, upload_status: 'pending')
      create(:audio_segment, project: project, upload_status: 'success')
      create(:audio_segment, project: project, upload_status: 'transcribed')
      create(:audio_segment, project: project, upload_status: 'failed')
    end

    describe '.successful' do
      it 'returns only successfully uploaded segments' do
        successful_segments = AudioSegment.successful
        expect(successful_segments.count).to eq(1)
        expect(successful_segments.first.upload_status).to eq('success')
      end
    end

    describe '.by_question' do
      let(:question) { create(:question) }
      let!(:segment_with_question) { create(:audio_segment, question: question) }
      let!(:segment_without_question) { create(:audio_segment, question: nil) }

      it 'returns segments for the specified question' do
        segments = AudioSegment.by_question(question.id)
        expect(segments.count).to eq(1)
        expect(segments.first).to eq(segment_with_question)
      end
    end
  end

  describe '#uploaded?' do
    it 'returns true when upload_status is success' do
      audio_segment.upload_status = 'success'
      expect(audio_segment.uploaded?).to be true
    end

    it 'returns false when upload_status is not success' do
      %w[pending uploading failed transcribed transcription_failed].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.uploaded?).to be false
      end
    end
  end

  describe '#transcribed?' do
    it 'returns true when upload_status is transcribed' do
      audio_segment.upload_status = 'transcribed'
      expect(audio_segment.transcribed?).to be true
    end

    it 'returns false when upload_status is not transcribed' do
      %w[pending uploading success failed transcription_failed].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.transcribed?).to be false
      end
    end
  end

  describe '#failed?' do
    it 'returns true when upload_status is failed or transcription_failed' do
      %w[failed transcription_failed].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.failed?).to be true
      end
    end

    it 'returns false when upload_status is not failed' do
      %w[pending uploading success transcribed].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.failed?).to be false
      end
    end
  end

  describe '#processing?' do
    it 'returns true when upload is in progress' do
      %w[pending uploading].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.processing?).to be true
      end
    end

    it 'returns false when upload is complete or failed' do
      %w[success failed transcribed transcription_failed].each do |status|
        audio_segment.upload_status = status
        expect(audio_segment.processing?).to be false
      end
    end
  end

  describe '#has_transcription?' do
    context 'when transcription_text is present' do
      let(:audio_segment) { build(:audio_segment, :transcribed) }

      it 'returns true' do
        expect(audio_segment.has_transcription?).to be true
      end
    end

    context 'when transcription_text is blank' do
      let(:audio_segment) { build(:audio_segment, transcription_text: nil) }

      it 'returns false' do
        expect(audio_segment.has_transcription?).to be false
      end
    end
  end

  describe '#estimated_transcription_time' do
    it 'estimates transcription time based on duration' do
      audio_segment.duration_seconds = 120 # 2 minutes
      
      # Assuming 1:4 ratio (transcription takes ~25% of audio duration)
      expected_time = 30 # 30 seconds
      expect(audio_segment.estimated_transcription_time).to eq(expected_time)
    end

    it 'handles nil duration gracefully' do
      audio_segment.duration_seconds = nil
      expect(audio_segment.estimated_transcription_time).to eq(60) # default fallback
    end
  end

  describe 'file format validation' do
    it 'accepts valid audio mime types' do
      valid_types = [
        'audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/m4a', 
        'audio/ogg', 'audio/webm', 'audio/flac'
      ]
      
      valid_types.each do |mime_type|
        audio_segment.mime_type = mime_type
        expect(audio_segment).to be_valid
      end
    end

    it 'accepts common audio file extensions' do
      valid_extensions = %w[.mp3 .wav .m4a .ogg .webm .flac]
      
      valid_extensions.each do |ext|
        audio_segment.file_name = "audio_file#{ext}"
        expect(audio_segment).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'creates a valid audio segment' do
      expect(build(:audio_segment)).to be_valid
    end

    it 'creates uploaded audio segment with trait' do
      uploaded_segment = create(:audio_segment, :uploaded)
      expect(uploaded_segment.upload_status).to eq('success')
    end

    it 'creates transcribed audio segment with trait' do
      transcribed_segment = create(:audio_segment, :transcribed)
      expect(transcribed_segment.upload_status).to eq('transcribed')
      expect(transcribed_segment.transcription_text).to be_present
    end

    it 'creates failed audio segment with trait' do
      failed_segment = create(:audio_segment, :failed)
      expect(failed_segment.upload_status).to eq('failed')
    end

    it 'creates audio segment without question using trait' do
      segment_without_question = create(:audio_segment, :without_question)
      expect(segment_without_question.question).to be_nil
    end
  end
end