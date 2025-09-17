require 'rails_helper'

RSpec.describe Question, type: :model do
  subject(:question) { build(:question) }

  describe 'associations' do
    it { is_expected.to belong_to(:section) }
    it { is_expected.to have_many(:audio_segments).dependent(:destroy) }
    it { is_expected.to have_one(:polly_audio_clip).dependent(:destroy) }
    it { is_expected.to belong_to(:parent_question).class_name('Question').optional }
    it { is_expected.to have_many(:follow_up_questions).class_name('Question').with_foreign_key('parent_question_id').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:text) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_uniqueness_of(:order).scoped_to([:section_id, :parent_question_id]) }
    
    context 'when validating uniqueness of order within section' do
      let!(:existing_question) { create(:question) }
      
      it 'validates uniqueness of order scoped to section' do
        new_question = build(:question, section: existing_question.section, order: existing_question.order)
        expect(new_question).not_to be_valid
        expect(new_question.errors[:order]).to include('has already been taken')
      end
      
      it 'allows same order in different sections' do
        different_section = create(:section)
        new_question = build(:question, section: different_section, order: existing_question.order)
        expect(new_question).to be_valid
      end
    end

    describe 'parent_question relationship' do
      it 'can have a parent question' do
        parent_question = create(:question, is_follow_up: false)
        child_question = build(:question, is_follow_up: true, parent_question: parent_question)
        expect(child_question).to be_valid
      end

      it 'can be a base question without parent' do
        question = build(:question, is_follow_up: false, parent_question: nil)
        expect(question).to be_valid
      end
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:text).of_type(:text) }
    it { is_expected.to have_db_column(:order).of_type(:integer) }
    it { is_expected.to have_db_column(:omitted).of_type(:boolean) }
    it { is_expected.to have_db_column(:skipped).of_type(:boolean) }
    it { is_expected.to have_db_column(:is_follow_up).of_type(:boolean) }
    it { is_expected.to have_db_column(:parent_question_id).of_type(:integer) }
    it { is_expected.to have_db_column(:section_id).of_type(:integer) }
  end

  describe 'scopes' do
    let!(:section) { create(:section) }
    let!(:question1) { create(:question, section: section, order: 1) }
    let!(:question2) { create(:question, section: section, order: 2) }
    let!(:omitted_question) { create(:question, section: section, order: 3, omitted: true) }
    let!(:skipped_question) { create(:question, section: section, order: 4, skipped: true) }
    let!(:followup_question) { create(:question, section: section, order: 5, is_follow_up: true, parent_question: question1) }

    describe '.by_order' do
      it 'returns questions ordered by order column' do
        expect(section.questions.by_order).to eq([question1, question2, omitted_question, skipped_question, followup_question])
      end
    end

    describe '.included' do
      it 'returns only non-omitted questions' do
        expect(Question.included).to match_array([question1, question2, skipped_question, followup_question])
      end
    end

    describe '.not_skipped' do
      it 'returns only non-skipped questions' do
        expect(Question.not_skipped).to match_array([question1, question2, omitted_question, followup_question])
      end
    end

    describe '.base_questions' do
      it 'returns only non-followup questions' do
        expect(Question.base_questions).to match_array([question1, question2, omitted_question, skipped_question])
      end
    end
  end

  describe 'instance methods' do
    describe '#omitted?' do
      it 'returns true when omitted is true' do
        question = build(:question, omitted: true)
        expect(question.omitted?).to be true
      end

      it 'returns false when omitted is false' do
        question = build(:question, omitted: false)
        expect(question.omitted?).to be false
      end

      it 'returns false when omitted is nil' do
        question = build(:question, omitted: nil)
        expect(question.omitted?).to be false
      end
    end

    describe '#skipped?' do
      it 'returns true when skipped is true' do
        question = build(:question, skipped: true)
        expect(question.skipped?).to be true
      end

      it 'returns false when skipped is false' do
        question = build(:question, skipped: false)
        expect(question.skipped?).to be false
      end

      it 'returns false when skipped is nil' do
        question = build(:question, skipped: nil)
        expect(question.skipped?).to be false
      end
    end

    describe '#is_follow_up?' do
      it 'returns true when is_follow_up is true' do
        question = build(:question, is_follow_up: true)
        expect(question.is_follow_up?).to be true
      end

      it 'returns false when is_follow_up is false' do
        question = build(:question, is_follow_up: false)
        expect(question.is_follow_up?).to be false
      end

      it 'returns false when is_follow_up is nil' do
        question = build(:question, is_follow_up: nil)
        expect(question.is_follow_up?).to be_falsy
      end
    end

    describe '#audio_segments association' do
      let(:question) { create(:question) }

      it 'can have audio segments' do
        audio_segment = create(:audio_segment, question: question, project: question.project)
        expect(question.audio_segments).to include(audio_segment)
      end

      it 'destroys audio segments when question is destroyed' do
        audio_segment = create(:audio_segment, question: question, project: question.project)
        expect { question.destroy }.to change { AudioSegment.count }.by(-1)
      end
    end

    describe '#project' do
      let(:project) { create(:project) }
      let(:chapter) { create(:chapter, project: project) }
      let(:section) { create(:section, chapter: chapter) }
      let(:question) { create(:question, section: section) }

      it 'returns the project through section and chapter associations' do
        expect(question.project).to eq(project)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid question' do
      expect(build(:question)).to be_valid
    end

    it 'creates a valid followup question' do
      parent = create(:question)
      followup = build(:question, :followup, parent_question: parent)
      expect(followup).to be_valid
      expect(followup.is_follow_up).to be true
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let!(:question) { create(:question) }
      let!(:audio_segment) { create(:audio_segment, question: question, project: question.project) }
      
      it 'destroys associated audio_segments when destroyed' do
        expect { question.destroy }.to change { AudioSegment.count }.by(-1)
      end
    end

    describe 'dependent destroy for follow_up questions' do
      let!(:parent_question) { create(:question) }
      let!(:followup_question) { create(:question, :followup, parent_question: parent_question) }

      it 'destroys follow_up questions when parent is destroyed' do
        expect { parent_question.destroy }.to change { Question.count }.by(-2)
      end
    end
  end

  describe 'edge cases' do
    describe 'long question text' do
      it 'handles very long question text' do
        long_text = 'a' * 10000
        question = build(:question, text: long_text)
        expect(question).to be_valid
      end
    end

    describe 'complex followup chains' do
      let!(:base_question) { create(:question) }
      let!(:followup1) { create(:question, :followup, parent_question: base_question) }
      let!(:followup2) { create(:question, :followup, parent_question: followup1) }

      it 'allows multi-level followup chains' do
        expect(followup2).to be_valid
        expect(base_question.follow_up_questions).to include(followup1)
        expect(followup1.follow_up_questions).to include(followup2)
      end

      it 'destroys entire chain when base question is destroyed' do
        expect { base_question.destroy }.to change { Question.count }.by(-3)
      end
    end

    describe 'ordering with mixed base and followup questions' do
      let(:section) { create(:section) }
      let!(:base1) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:followup1) { create(:question, section: section, order: 2, is_follow_up: true, parent_question: base1) }
      let!(:base2) { create(:question, section: section, order: 3, is_follow_up: false) }
      let!(:followup2) { create(:question, section: section, order: 4, is_follow_up: true, parent_question: base2) }

      it 'maintains correct ordering regardless of question type' do
        expect(section.questions.by_order).to eq([base1, followup1, base2, followup2])
      end
    end
  end
end