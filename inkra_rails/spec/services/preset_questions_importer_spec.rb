require 'rails_helper'

RSpec.describe PresetQuestionsImporter do
  let(:temp_dir) { Dir.mktmpdir }
  let(:sample_yaml_content) do
    {
      'uuid' => SecureRandom.uuid,
      'title' => 'Test Preset',
      'description' => 'A test preset for unit testing',
      'llm_prompt' => 'You are a test facilitator.',
      'questions' => [
        'What is your first question?',
        'What is your second question?',
        'What is your third question?'
      ]
    }
  end

  before do
    stub_const("PresetQuestionsImporter::PRESET_QUESTIONS_DIR", Pathname.new(temp_dir))
  end

  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe '.import_all' do
    it 'delegates to instance method' do
      importer_instance = instance_double(PresetQuestionsImporter)
      expect(PresetQuestionsImporter).to receive(:new).and_return(importer_instance)
      expect(importer_instance).to receive(:import_all)
      
      PresetQuestionsImporter.import_all
    end
  end

  describe '#import_all' do
    let(:importer) { PresetQuestionsImporter.new }

    context 'with valid YAML files' do
      before do
        # Create test YAML file
        File.write(File.join(temp_dir, 'test_preset.yaml'), sample_yaml_content.to_yaml)
      end

      it 'imports preset successfully' do
        expect {
          result = importer.import_all
          expect(result[:imported]).to eq(1)
          expect(result[:updated]).to eq(0)
          expect(result[:errors]).to be_empty
        }.to change(InterviewPreset, :count).by(1)
        
        preset = InterviewPreset.last
        expect(preset.title).to eq('Test Preset')
        expect(preset.description).to eq('A test preset for unit testing')
        expect(preset.preset_questions.count).to eq(3)
      end

      it 'updates existing preset when UUID matches' do
        # Create an existing preset first
        existing_preset = create(:interview_preset, uuid: sample_yaml_content['uuid'])
        
        # Modify YAML content with same UUID but different title
        updated_content = sample_yaml_content.merge('title' => 'Updated Test Preset')
        File.write(File.join(temp_dir, 'test_preset.yaml'), updated_content.to_yaml)
        
        expect {
          result = importer.import_all
          expect(result[:imported]).to eq(0)
          expect(result[:updated]).to eq(1)
          expect(result[:errors]).to be_empty
        }.not_to change(InterviewPreset, :count)
        
        existing_preset.reload
        expect(existing_preset.title).to eq('Updated Test Preset')
      end

      it 'adds UUID to YAML file if missing' do
        # Create YAML without UUID
        yaml_without_uuid = sample_yaml_content.except('uuid')
        file_path = File.join(temp_dir, 'no_uuid.yaml')
        File.write(file_path, yaml_without_uuid.to_yaml)
        
        importer.import_all
        
        # Check that UUID was added to file
        updated_content = YAML.load_file(file_path)
        expect(updated_content['uuid']).to be_present
        expect(updated_content['uuid']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it 'creates questions with proper structure' do
        importer.import_all
        
        preset = InterviewPreset.last
        questions = preset.preset_questions.ordered
        
        expect(questions.count).to eq(3)
        
        questions.each_with_index do |question, index|
          expect(question.chapter_title).to eq('Main Questions')
          expect(question.section_title).to eq('Core Questions')
          expect(question.chapter_order).to eq(1)
          expect(question.section_order).to eq(1)
          expect(question.question_order).to eq(index + 1)
          expect(question.question_text).to eq(sample_yaml_content['questions'][index])
        end
      end
    end

    context 'with invalid YAML files' do
      before do
        # Create invalid YAML file
        File.write(File.join(temp_dir, 'invalid.yaml'), "invalid: yaml: content:\n  - malformed")
      end

      it 'handles errors gracefully' do
        result = importer.import_all
        
        expect(result[:imported]).to eq(0)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include('invalid.yaml')
      end
    end

    context 'with empty directory' do
      it 'returns zero counts' do
        result = importer.import_all
        
        expect(result[:imported]).to eq(0)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end
  end

  describe '#determine_category' do
    let(:importer) { PresetQuestionsImporter.new }

    it 'categorizes based on title keywords' do
      expect(importer.send(:determine_category, 'Creative Breakthrough', 'creative_test')).to eq('creativity')
      expect(importer.send(:determine_category, 'Question Mastery', 'question_test')).to eq('self_inquiry')
      expect(importer.send(:determine_category, 'Leadership Skills', 'leadership_test')).to eq('leadership')
      expect(importer.send(:determine_category, 'Relationship Building', 'relationship_test')).to eq('relationships')
      expect(importer.send(:determine_category, 'Mindset Transformation', 'mindset_test')).to eq('mindset')
      expect(importer.send(:determine_category, 'Personal Growth', 'growth_test')).to eq('personal_growth')
      expect(importer.send(:determine_category, 'Random Title', 'random_file')).to eq('general')
    end

    it 'categorizes based on filename when title is ambiguous' do
      expect(importer.send(:determine_category, 'Test', 'creative_something')).to eq('creativity')
      expect(importer.send(:determine_category, 'Test', 'leadership_guide')).to eq('leadership')
    end
  end

  describe '#determine_icon' do
    let(:importer) { PresetQuestionsImporter.new }

    it 'assigns appropriate icons based on category' do
      expect(importer.send(:determine_icon, 'Creative Test', 'creative')).to eq('lightbulb.fill')
      expect(importer.send(:determine_icon, 'Question Test', 'question')).to eq('questionmark.circle.fill')
      expect(importer.send(:determine_icon, 'Leadership Test', 'leadership')).to eq('person.3.fill')
      expect(importer.send(:determine_icon, 'Relationship Test', 'relationship')).to eq('heart.fill')
      expect(importer.send(:determine_icon, 'Mindset Test', 'mindset')).to eq('brain.head.profile')
      expect(importer.send(:determine_icon, 'Growth Test', 'growth')).to eq('arrow.up.circle.fill')
      expect(importer.send(:determine_icon, 'Random Test', 'random')).to eq('star.fill')
    end
  end

  describe '#determine_order_position' do
    let(:importer) { PresetQuestionsImporter.new }

    it 'generates consistent order based on filename' do
      position1 = importer.send(:determine_order_position, 'test_file_a')
      position2 = importer.send(:determine_order_position, 'test_file_a')
      position3 = importer.send(:determine_order_position, 'test_file_b')
      
      expect(position1).to eq(position2) # Same filename = same position
      expect(position1).not_to eq(position3) # Different filename = different position
      expect(position1).to be_between(0, 999)
    end
  end
end