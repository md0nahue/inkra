require 'rails_helper'

RSpec.describe Chapter, type: :model do
  subject(:chapter) { build(:chapter) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:sections).dependent(:destroy) }
    it { is_expected.to have_many(:questions).through(:sections) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_uniqueness_of(:order).scoped_to(:project_id) }
    
    context 'when validating uniqueness of order within project' do
      let!(:existing_chapter) { create(:chapter) }
      
      it 'validates uniqueness of order scoped to project' do
        new_chapter = build(:chapter, project: existing_chapter.project, order: existing_chapter.order)
        expect(new_chapter).not_to be_valid
        expect(new_chapter.errors[:order]).to include('has already been taken')
      end
      
      it 'allows same order in different projects' do
        different_project = create(:project)
        new_chapter = build(:chapter, project: different_project, order: existing_chapter.order)
        expect(new_chapter).to be_valid
      end
    end
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:title).of_type(:string) }
    it { is_expected.to have_db_column(:order).of_type(:integer) }
    it { is_expected.to have_db_column(:omitted).of_type(:boolean) }
    it { is_expected.to have_db_column(:project_id).of_type(:integer) }
  end

  describe 'scopes' do
    let!(:project) { create(:project) }
    let!(:chapter1) { create(:chapter, project: project, order: 1) }
    let!(:chapter2) { create(:chapter, project: project, order: 2) }
    let!(:omitted_chapter) { create(:chapter, project: project, order: 3, omitted: true) }

    describe '.by_order' do
      it 'returns chapters ordered by order column' do
        expect(project.chapters.by_order).to eq([chapter1, chapter2, omitted_chapter])
      end
    end

    describe '.included' do
      it 'returns only non-omitted chapters' do
        expect(Chapter.included).to match_array([chapter1, chapter2])
      end
    end
  end

  describe '#omitted?' do
    context 'when chapter is omitted' do
      let(:chapter) { build(:chapter, omitted: true) }
      
      it 'returns true' do
        expect(chapter.omitted?).to be true
      end
    end

    context 'when chapter is not omitted' do
      let(:chapter) { build(:chapter, omitted: false) }
      
      it 'returns false' do
        expect(chapter.omitted?).to be false
      end
    end

    context 'when omitted is nil' do
      let(:chapter) { build(:chapter, omitted: nil) }
      
      it 'returns false' do
        expect(chapter.omitted?).to be false
      end
    end
  end

  describe '#questions association' do
    let(:chapter) { create(:chapter) }
    
    before do
      section1 = create(:section, chapter: chapter)
      section2 = create(:section, chapter: chapter)
      create_list(:question, 2, section: section1)
      create_list(:question, 3, section: section2)
    end

    it 'returns all questions through sections' do
      expect(chapter.questions.count).to eq(5)
    end
  end

  describe '#sections association' do
    let(:chapter) { create(:chapter) }
    
    before do
      create_list(:section, 3, chapter: chapter)
    end

    it 'returns all sections' do
      expect(chapter.sections.count).to eq(3)
    end
  end

  describe 'factory' do
    it 'creates a valid chapter' do
      expect(build(:chapter)).to be_valid
    end

    it 'creates a valid chapter with sections' do
      chapter_with_sections = create(:chapter_with_sections)
      expect(chapter_with_sections).to be_valid
      expect(chapter_with_sections.sections.count).to be > 0
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let!(:chapter) { create(:chapter_with_sections) }
      let!(:section_ids) { chapter.sections.pluck(:id) }
      
      it 'destroys associated sections when chapter is destroyed' do
        expect { chapter.destroy }.to change { Section.count }.by(-chapter.sections.count)
        expect(Section.where(id: section_ids)).to be_empty
      end
    end
  end
end