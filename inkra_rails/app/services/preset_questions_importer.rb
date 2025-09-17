require 'yaml'
require 'securerandom'

class PresetQuestionsImporter
  PRESET_QUESTIONS_DIR = Rails.root.join('db', 'preset_questions')

  def self.import_all
    new.import_all
  end

  def initialize
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  def import_all
    Rails.logger.info "Starting preset questions import from #{PRESET_QUESTIONS_DIR}"
    
    yaml_files.each do |file_path|
      begin
        import_file(file_path)
      rescue => e
        @errors << "Error importing #{File.basename(file_path)}: #{e.message}"
        Rails.logger.error "Error importing #{file_path}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    log_summary
    { imported: @imported_count, updated: @updated_count, errors: @errors }
  end

  private

  def yaml_files
    Dir.glob(File.join(PRESET_QUESTIONS_DIR, '*.yaml'))
  end

  def import_file(file_path)
    filename = File.basename(file_path, '.yaml')
    yaml_content = YAML.load_file(file_path)
    
    # Add UUID if not present
    if yaml_content['uuid'].blank?
      yaml_content['uuid'] = SecureRandom.uuid
      save_yaml_with_uuid(file_path, yaml_content)
      Rails.logger.info "Added UUID to #{filename}"
    end

    import_interview_preset(yaml_content, filename)
  end

  def save_yaml_with_uuid(file_path, yaml_content)
    # Reorder content to have uuid at the top
    ordered_content = {
      'uuid' => yaml_content['uuid'],
      'title' => yaml_content['title'],
      'description' => yaml_content['description'],
      'llm_prompt' => yaml_content['llm_prompt'],
      'questions' => yaml_content['questions']
    }

    File.write(file_path, ordered_content.to_yaml)
  end

  def import_interview_preset(yaml_content, filename)
    preset = InterviewPreset.find_or_initialize_by(uuid: yaml_content['uuid'])
    
    if preset.persisted?
      @updated_count += 1
      Rails.logger.info "Updating existing preset: #{yaml_content['title']}"
    else
      @imported_count += 1
      Rails.logger.info "Creating new preset: #{yaml_content['title']}"
    end

    preset.assign_attributes(
      title: yaml_content['title'],
      description: yaml_content['description'],
      category: determine_category(yaml_content['title'], filename),
      icon_name: determine_icon(yaml_content['title'], filename),
      order_position: determine_order_position(filename),
      active: true
    )

    preset.save!

    # Import questions
    import_questions_for_preset(preset, yaml_content)
  end

  def import_questions_for_preset(preset, yaml_content)
    # Clear existing questions to avoid duplicates
    preset.preset_questions.destroy_all

    questions = yaml_content['questions'] || []
    questions.each_with_index do |question_text, index|
      PresetQuestion.create!(
        interview_preset: preset,
        chapter_title: 'Main Questions',
        section_title: 'Core Questions',
        question_text: question_text,
        chapter_order: 1,
        section_order: 1,
        question_order: index + 1
      )
    end

    Rails.logger.info "Imported #{questions.size} questions for #{preset.title}"
  end

  def determine_category(title, filename)
    # Simple categorization based on keywords in title/filename
    title_lower = title.downcase
    filename_lower = filename.downcase

    case
    when title_lower.include?('creative') || title_lower.include?('innovation') || filename_lower.include?('creative')
      'creativity'
    when title_lower.include?('question') || title_lower.include?('inquiry') || filename_lower.include?('question')
      'self_inquiry'
    when title_lower.include?('leadership') || title_lower.include?('influence') || filename_lower.include?('leadership')
      'leadership'
    when title_lower.include?('relationship') || title_lower.include?('connection') || filename_lower.include?('relationship')
      'relationships'
    when title_lower.include?('mindset') || title_lower.include?('mindful') || title_lower.include?('mental')
      'mindset'
    when title_lower.include?('growth') || title_lower.include?('transformation') || title_lower.include?('development')
      'personal_growth'
    else
      'general'
    end
  end

  def determine_icon(title, filename)
    # Simple icon assignment based on category
    category = determine_category(title, filename)
    
    case category
    when 'creativity'
      'lightbulb.fill'
    when 'self_inquiry'
      'questionmark.circle.fill'
    when 'leadership'
      'person.3.fill'
    when 'relationships'
      'heart.fill'
    when 'mindset'
      'brain.head.profile'
    when 'personal_growth'
      'arrow.up.circle.fill'
    else
      'star.fill'
    end
  end

  def determine_order_position(filename)
    # Use a hash of the filename to create consistent ordering
    filename.bytes.sum % 1000
  end

  def log_summary
    Rails.logger.info "Preset questions import completed: #{@imported_count} imported, #{@updated_count} updated"
    @errors.each { |error| Rails.logger.error error }
  end
end