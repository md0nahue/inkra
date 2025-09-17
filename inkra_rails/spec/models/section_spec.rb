require 'rails_helper'

RSpec.describe Section, type: :model do
  subject(:section) { build(:section) }

  describe 'associations' do
    it { is_expected.to belong_to(:chapter) }
    it { is_expected.to have_many(:questions).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_uniqueness_of(:order).scoped_to(:chapter_id) }
    
    context 'when validating uniqueness of order within chapter' do
      let!(:existing_section) { create(:section) }
      
      it 'validates uniqueness of order scoped to chapter' do
        new_section = build(:section, chapter: existing_section.chapter, order: existing_section.order)
        expect(new_section).not_to be_valid
        expect(new_section.errors[:order]).to include('has already been taken')
      end
      
      it 'allows same order in different chapters' do
        different_chapter = create(:chapter)
        new_section = build(:section, chapter: different_chapter, order: existing_section.order)
        expect(new_section).to be_valid
      end
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:title).of_type(:string) }
    it { is_expected.to have_db_column(:order).of_type(:integer) }
    it { is_expected.to have_db_column(:omitted).of_type(:boolean) }
    it { is_expected.to have_db_column(:chapter_id).of_type(:integer) }
  end

  describe 'scopes' do
    let!(:chapter) { create(:chapter) }
    let!(:section1) { create(:section, chapter: chapter, order: 1) }
    let!(:section2) { create(:section, chapter: chapter, order: 2) }
    let!(:omitted_section) { create(:section, chapter: chapter, order: 3, omitted: true) }

    describe '.by_order' do
      it 'returns sections ordered by order column' do
        expect(chapter.sections.by_order).to eq([section1, section2, omitted_section])
      end
    end

    describe '.included' do
      it 'returns only non-omitted sections' do
        expect(Section.included).to match_array([section1, section2])
      end
    end
  end

  describe '#omitted?' do
    context 'when section is omitted' do
      let(:section) { build(:section, omitted: true) }
      
      it 'returns true' do
        expect(section.omitted?).to be true
      end
    end

    context 'when section is not omitted' do
      let(:section) { build(:section, omitted: false) }
      
      it 'returns false' do
        expect(section.omitted?).to be false
      end
    end

    context 'when omitted is nil' do
      let(:section) { build(:section, omitted: nil) }
      
      it 'returns false' do
        expect(section.omitted?).to be false
      end
    end
  end

  describe '#questions association' do
    let(:section) { create(:section) }
    
    context 'when section has questions' do
      before do
        create_list(:question, 4, section: section)
      end

      it 'returns all questions' do
        expect(section.questions.count).to eq(4)
      end
    end

    context 'when section has no questions' do
      it 'returns empty collection' do
        expect(section.questions.count).to eq(0)
      end
    end
  end

  describe 'through associations' do
    let(:project) { create(:project) }
    let(:chapter) { create(:chapter, project: project) }
    let(:section) { create(:section, chapter: chapter) }

    it 'can access project through chapter' do
      expect(section.chapter.project).to eq(project)
    end
  end

  describe 'factory' do
    it 'creates a valid section' do
      expect(build(:section)).to be_valid
    end

    it 'creates a valid section with questions' do
      section_with_questions = create(:section_with_questions)
      expect(section_with_questions).to be_valid
      expect(section_with_questions.questions.count).to be > 0
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let!(:section) { create(:section_with_questions) }
      let!(:question_ids) { section.questions.pluck(:id) }
      
      it 'destroys associated questions when section is destroyed' do
        expect { section.destroy }.to change { Question.count }.by(-section.questions.count)
        expect(Question.where(id: question_ids)).to be_empty
      end
    end
  end

  describe 'edge cases' do
    describe 'when chapter is destroyed' do
      let!(:chapter) { create(:chapter) }
      let!(:section) { create(:section, chapter: chapter) }
      
      it 'is destroyed along with chapter' do
        expect { chapter.destroy }.to change { Section.count }.by(-1)
        expect { section.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'ordering with gaps' do
      let(:chapter) { create(:chapter) }
      let!(:section1) { create(:section, chapter: chapter, order: 1) }
      let!(:section3) { create(:section, chapter: chapter, order: 3) }
      let!(:section5) { create(:section, chapter: chapter, order: 5) }

      it 'maintains order correctly with gaps' do
        expect(chapter.sections.by_order).to eq([section1, section3, section5])
      end
    end
  end
end