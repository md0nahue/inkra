require 'rails_helper'

RSpec.describe Project, type: :model do
  subject(:project) { build(:project) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:topic) }
    
    describe 'status validation' do
      it 'accepts valid status values' do
        valid_statuses = %w[outline_generating outline_ready recording_in_progress transcribing completed failed]
        valid_statuses.each do |status|
          project.status = status
          expect(project).to be_valid
        end
      end
      
      it 'rejects invalid status values' do
        expect { project.status = 'invalid_status' }.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:chapters).dependent(:destroy) }
    it { is_expected.to have_many(:sections).through(:chapters) }
    it { is_expected.to have_many(:questions).through(:sections) }
    it { is_expected.to have_many(:audio_segments).dependent(:destroy) }
    it { is_expected.to have_one(:transcript).dependent(:destroy) }
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:title).of_type(:string) }
    it { is_expected.to have_db_column(:topic).of_type(:text) }
    it { is_expected.to have_db_column(:status).of_type(:string) }
    it { is_expected.to have_db_column(:last_modified_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:user_id).of_type(:integer) }
  end

  describe 'callbacks' do
    it 'sets last_modified_at before save' do
      freeze_time = Time.current
      allow(Time).to receive(:current).and_return(freeze_time)
      
      project = build(:project)
      project.save!
      
      expect(project.last_modified_at).to eq(freeze_time)
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:outline_generating_project) { create(:project, user: user, status: 'outline_generating') }
    let!(:outline_ready_project) { create(:project, user: user, status: 'outline_ready') }
    let!(:completed_project) { create(:project, user: user, status: 'completed') }
    let!(:failed_project) { create(:project, user: user, status: 'failed') }

    describe '.by_status' do
      it 'filters projects by status' do
        completed_projects = Project.by_status('completed')
        expect(completed_projects).to include(completed_project)
        expect(completed_projects).not_to include(failed_project)
      end
    end

    describe '.active' do
      it 'returns only non-failed projects' do
        active_projects = Project.active
        expect(active_projects).to include(outline_generating_project, outline_ready_project, completed_project)
        expect(active_projects).not_to include(failed_project)
      end
    end
  end

  describe '#outline_status' do
    context 'when project has no chapters' do
      it 'returns "not_started"' do
        expect(project.outline_status).to eq('not_started')
      end
    end

    context 'when project has chapters' do
      let(:project) { create(:project_with_outline) }

      it 'returns "ready"' do
        expect(project.outline_status).to eq('ready')
      end
    end

    context 'when project status is outline_generating' do
      let(:project) { build(:project, status: 'outline_generating') }

      it 'returns "generating"' do
        expect(project.outline_status).to eq('generating')
      end
    end
  end

  describe '#completed?' do
    it 'returns true when status is completed' do
      project.status = 'completed'
      expect(project.completed?).to be true
    end

    it 'returns false when status is not completed' do
      project.status = 'outline_ready'
      expect(project.completed?).to be false
    end
  end

  describe '#failed?' do
    it 'returns true when status is failed' do
      project.status = 'failed'
      expect(project.failed?).to be true
    end

    it 'returns false when status is not failed' do
      project.status = 'completed'
      expect(project.failed?).to be false
    end
  end

  describe '#can_record?' do
    it 'always returns true regardless of status' do
      %w[outline_generating outline_ready recording_in_progress transcribing completed failed].each do |status|
        project.status = status
        expect(project.can_record?).to be true
      end
    end
  end

  describe '#transcript_ready?' do
    context 'when project has no transcript' do
      it 'returns false' do
        expect(project.transcript_ready?).to be false
      end
    end

    context 'when project has transcript with ready status' do
      let(:project) { create(:project) }
      let!(:transcript) { create(:transcript, project: project, status: :ready) }

      it 'returns true' do
        project.reload # Ensure association is loaded
        expect(project.transcript).to eq(transcript)
        expect(project.transcript.status).to eq('ready')
        expect(project.transcript_ready?).to be true
      end
    end

    context 'when project has transcript with processing_raw status' do
      let(:project) { create(:project) }
      
      before do
        create(:transcript, project: project, status: :processing_raw)
      end

      it 'returns false' do
        expect(project.transcript_ready?).to be false
      end
    end
  end

  describe '#ready_for_sharing?' do
    context 'when project has audio content' do
      before do
        allow(project).to receive(:has_audio_content?).and_return(true)
      end

      it 'returns true regardless of completion status' do
        project.status = 'recording_in_progress'
        expect(project.ready_for_sharing?).to be true
      end
    end

    context 'when project has substantial transcript content' do
      before do
        allow(project).to receive(:has_audio_content?).and_return(false)
        transcript = build(:transcript, raw_content: 'a' * 150) # More than 100 chars
        allow(project).to receive(:transcript).and_return(transcript)
      end

      it 'returns true regardless of completion status' do
        project.status = 'transcribing'
        expect(project.ready_for_sharing?).to be true
      end
    end

    context 'when project has insufficient transcript content' do
      before do
        allow(project).to receive(:has_audio_content?).and_return(false)
        transcript = build(:transcript, raw_content: 'short') # Less than 100 chars
        allow(project).to receive(:transcript).and_return(transcript)
      end

      it 'returns false' do
        expect(project.ready_for_sharing?).to be false
      end
    end

    context 'when project has no content' do
      before do
        allow(project).to receive(:has_audio_content?).and_return(false)
        allow(project).to receive(:transcript).and_return(nil)
      end

      it 'returns false' do
        expect(project.ready_for_sharing?).to be false
      end
    end
  end

  describe '#sharing_status' do
    context 'when project has meaningful content and is completed' do
      before do
        allow(project).to receive(:has_meaningful_content?).and_return(true)
        project.status = 'completed'
      end

      it 'returns complete' do
        expect(project.sharing_status).to eq('complete')
      end
    end

    context 'when project has meaningful content but is not completed' do
      before do
        allow(project).to receive(:has_meaningful_content?).and_return(true)
        project.status = 'recording_in_progress'
      end

      it 'returns partial' do
        expect(project.sharing_status).to eq('partial')
      end
    end

    context 'when project has no meaningful content' do
      before do
        allow(project).to receive(:has_meaningful_content?).and_return(false)
      end

      it 'returns not_ready' do
        expect(project.sharing_status).to eq('not_ready')
      end
    end
  end

  describe 'factory' do
    it 'creates a valid project' do
      expect(build(:project)).to be_valid
    end

    it 'creates a project with outline using factory' do
      project_with_outline = create(:project_with_outline)
      expect(project_with_outline.chapters.count).to eq(2)
      expect(project_with_outline.sections.count).to be > 0
      expect(project_with_outline.questions.count).to be > 0
    end

    it 'creates projects with different statuses using traits' do
      recording_project = create(:project, :recording_in_progress)
      expect(recording_project.status).to eq('recording_in_progress')

      transcribing_project = create(:project, :transcribing)
      expect(transcribing_project.status).to eq('transcribing')

      completed_project = create(:project, :completed)
      expect(completed_project.status).to eq('completed')

      failed_project = create(:project, :failed)
      expect(failed_project.status).to eq('failed')
    end
  end
end