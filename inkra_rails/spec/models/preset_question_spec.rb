require 'rails_helper'

RSpec.describe PresetQuestion, type: :model do
  let(:interview_preset) { create(:interview_preset) }
  let(:preset_question) { create(:preset_question, interview_preset: interview_preset) }

  describe 'associations' do
    it { should belong_to(:interview_preset) }
  end

  describe 'validations' do
    it { should validate_presence_of(:chapter_title) }
    it { should validate_presence_of(:section_title) }
    it { should validate_presence_of(:question_text) }
    it { should validate_presence_of(:chapter_order) }
    it { should validate_presence_of(:section_order) }
    it { should validate_presence_of(:question_order) }
    
    it { should validate_numericality_of(:chapter_order).is_greater_than(0) }
    it { should validate_numericality_of(:section_order).is_greater_than(0) }
    it { should validate_numericality_of(:question_order).is_greater_than(0) }
  end

  describe 'scopes' do
    let!(:question1) { create(:preset_question, chapter_order: 2, section_order: 1, question_order: 2) }
    let!(:question2) { create(:preset_question, chapter_order: 1, section_order: 2, question_order: 1) }
    let!(:question3) { create(:preset_question, chapter_order: 1, section_order: 1, question_order: 1) }

    describe '.ordered' do
      it 'orders by chapter_order, section_order, question_order' do
        expect(PresetQuestion.ordered).to eq([question3, question2, question1])
      end
    end

    describe '.by_chapter' do
      it 'filters by chapter title' do
        chapter1_question = create(:preset_question, chapter_title: 'Chapter 1')
        chapter2_question = create(:preset_question, chapter_title: 'Chapter 2')
        
        expect(PresetQuestion.by_chapter('Chapter 1')).to include(chapter1_question)
        expect(PresetQuestion.by_chapter('Chapter 1')).not_to include(chapter2_question)
      end
    end

    describe '.by_section' do
      it 'filters by section title' do
        section1_question = create(:preset_question, section_title: 'Section 1')
        section2_question = create(:preset_question, section_title: 'Section 2')
        
        expect(PresetQuestion.by_section('Section 1')).to include(section1_question)
        expect(PresetQuestion.by_section('Section 1')).not_to include(section2_question)
      end
    end
  end

  describe '#chapter_and_section' do
    it 'returns formatted chapter and section' do
      question = create(:preset_question, 
                       chapter_title: 'Introduction', 
                       section_title: 'Getting Started')
      
      expect(question.chapter_and_section).to eq('Introduction - Getting Started')
    end
  end

  describe '#full_order_key' do
    it 'returns array of order values' do
      question = create(:preset_question,
                       chapter_order: 1,
                       section_order: 2, 
                       question_order: 3)
      
      expect(question.full_order_key).to eq([1, 2, 3])
    end
  end
end