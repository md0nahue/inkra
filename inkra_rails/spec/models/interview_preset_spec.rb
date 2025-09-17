require 'rails_helper'

RSpec.describe InterviewPreset, type: :model do
  # Test data setup
  let(:user) { create(:user) }
  let(:preset) { create(:interview_preset) }
  let(:inactive_preset) { create(:interview_preset, active: false) }
  
  subject { build(:interview_preset) }
  
  describe 'associations' do
    it { should have_many(:preset_questions).dependent(:destroy) }
    it { should have_many(:projects) }
    it { should have_many(:user_shown_interview_presets).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:icon_name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid).case_insensitive }
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns only active presets' do
        active_preset = create(:interview_preset, active: true)
        inactive_preset = create(:interview_preset, active: false)
        
        expect(InterviewPreset.active).to include(active_preset)
        expect(InterviewPreset.active).not_to include(inactive_preset)
      end
    end

    describe '.featured' do
      it 'returns only featured presets' do
        featured_preset = create(:interview_preset, is_featured: true)
        regular_preset = create(:interview_preset, is_featured: false)
        
        expect(InterviewPreset.featured).to include(featured_preset)
        expect(InterviewPreset.featured).not_to include(regular_preset)
      end
    end

    describe '.by_category' do
      it 'returns presets of specified category' do
        creativity_preset = create(:interview_preset, category: 'creativity')
        growth_preset = create(:interview_preset, category: 'personal_growth')
        
        expect(InterviewPreset.by_category('creativity')).to include(creativity_preset)
        expect(InterviewPreset.by_category('creativity')).not_to include(growth_preset)
      end
    end

    describe '.ordered' do
      it 'orders by order_position then title' do
        preset_c = create(:interview_preset, title: 'C Preset', order_position: 2)
        preset_a = create(:interview_preset, title: 'A Preset', order_position: 1)
        preset_b = create(:interview_preset, title: 'B Preset', order_position: 1)
        
        expected_order = [preset_a, preset_b, preset_c]
        expect(InterviewPreset.ordered).to eq(expected_order)
      end
    end
  end

  describe '#to_param' do
    it 'returns uuid' do
      expect(preset.to_param).to eq(preset.uuid)
    end
  end

  describe '#questions_grouped_by_chapter' do
    it 'groups preset questions by chapter title' do
      chapter1_q1 = create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', chapter_order: 1, section_order: 1, question_order: 1)
      chapter1_q2 = create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', chapter_order: 1, section_order: 1, question_order: 2)
      chapter2_q1 = create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 2', chapter_order: 2, section_order: 1, question_order: 1)

      grouped = preset.questions_grouped_by_chapter
      
      expect(grouped.keys).to contain_exactly('Chapter 1', 'Chapter 2')
      expect(grouped['Chapter 1']).to contain_exactly(chapter1_q1, chapter1_q2)
      expect(grouped['Chapter 2']).to contain_exactly(chapter2_q1)
    end
  end

  describe '#total_questions_count' do
    it 'returns the count of associated preset questions' do
      create_list(:preset_question, 3, interview_preset: preset)
      
      expect(preset.total_questions_count).to eq(3)
    end
  end

  describe '#shown_to_user?' do
    context 'when preset has been shown to user' do
      it 'returns true' do
        create(:user_shown_interview_preset, user: user, interview_preset: preset)
        
        expect(preset.shown_to_user?(user)).to be true
      end
    end

    context 'when preset has not been shown to user' do
      it 'returns false' do
        expect(preset.shown_to_user?(user)).to be false
      end
    end

    context 'when user is nil' do
      it 'returns false' do
        expect(preset.shown_to_user?(nil)).to be false
      end
    end
  end

  describe '#mark_as_shown_to_user' do
    context 'when user is provided' do
      it 'creates a user_shown_interview_preset record' do
        expect {
          preset.mark_as_shown_to_user(user)
        }.to change(UserShownInterviewPreset, :count).by(1)
        
        shown_record = UserShownInterviewPreset.last
        expect(shown_record.user).to eq(user)
        expect(shown_record.interview_preset).to eq(preset)
        expect(shown_record.shown_at).to be_within(1.second).of(Time.current)
      end

      it 'does not create duplicate records' do
        preset.mark_as_shown_to_user(user)
        
        expect {
          preset.mark_as_shown_to_user(user)
        }.not_to change(UserShownInterviewPreset, :count)
      end
    end

    context 'when user is nil' do
      it 'does not create a record' do
        expect {
          preset.mark_as_shown_to_user(nil)
        }.not_to change(UserShownInterviewPreset, :count)
      end
    end
  end
end