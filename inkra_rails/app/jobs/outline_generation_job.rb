class OutlineGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(project_id)
    Rails.logger.debug "\n🏗️🚀 OUTLINE GENERATION JOB STARTED"
    Rails.logger.debug "━" * 50
    Rails.logger.debug "🆔 Project ID: #{project_id}"
    
    project = Project.find_by(id: project_id)
    unless project
      Rails.logger.warn "OutlineGenerationJob: Project with id #{project_id} not found, skipping job"
      return
    end
    
    Rails.logger.debug "📝 Project Topic: \"#{project.topic}\""
    Rails.logger.debug "🎙️ Is Speech Interview: #{project.is_speech_interview}"
    Rails.logger.debug "📊 Current Status: #{project.status}"
    
    begin
      # Set status to generating if not already set
      if project.status != 'outline_generating'
        project.update!(status: 'outline_generating')
      end
      
      # Use LLM service to generate interview outline
      service = InterviewQuestionService.new
      Rails.logger.debug "InterviewQuestionService instantiated"
      
      # Determine generation options based on interview length
      options = determine_question_options(project)
      Rails.logger.debug "Using generation options: #{options.inspect}"
      
      outline = service.generate_interview_outline(project.topic, options)
      Rails.logger.debug "LLM service returned outline with #{outline[:chapters]&.length || 0} chapters"
      
      if outline[:error]
        Rails.logger.error "Outline generation failed: #{outline[:error]}"
        project.update!(status: 'failed')
        return
      end
      
      # Create chapters, sections, and questions from LLM-generated outline
      Rails.logger.debug "Creating chapters from outline..."
      new_question_ids = []
      
      ActiveRecord::Base.transaction do
        outline[:chapters]&.each do |chapter_data|
          Rails.logger.debug "Creating chapter: #{chapter_data[:title]}"
          chapter = project.chapters.create!(
            title: chapter_data[:title],
            order: chapter_data[:order],
            omitted: false
          )
          
          chapter_data[:sections]&.each do |section_data|
            Rails.logger.debug "Creating section: #{section_data[:title]}"
            section = chapter.sections.create!(
              title: section_data[:title],
              order: section_data[:order],
              omitted: false
            )
            
            section_data[:questions]&.each do |question_data|
              question = section.questions.create!(
                text: question_data[:text],
                order: question_data[:order]
              )
              
              # Collect question IDs for post-transaction job enqueueing
              if project.is_speech_interview
                new_question_ids << question.id
              end
            end
          end
        end
      end
      
      # Update project status to outline_ready
      Rails.logger.debug "Updating project status to outline_ready"
      project.update!(status: 'outline_ready')
      
      # Enqueue Polly jobs after transaction commits to ensure questions exist
      if project.is_speech_interview && new_question_ids.any?
        Rails.logger.debug "Enqueueing Polly jobs for #{new_question_ids.length} questions"
        new_question_ids.each do |question_id|
          PollyGenerationJob.perform_later(
            question_id,
            voice_id: project.voice_id || 'Joanna',
            speech_rate: project.speech_rate || 100
          )
        end
      end
      
      Rails.logger.info "✅ Successfully generated outline for project #{project_id} with #{new_question_ids.length} questions"
      Rails.logger.debug "━" * 50
      
    rescue StandardError => e
      Rails.logger.error "❌ Failed to generate outline for project #{project_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      Rails.logger.debug "━" * 50
      project.update!(status: 'failed')
      raise
    end
  end
  
  private
  
  def determine_question_options(project)
    # Use question_count if provided, otherwise determine from interview_length
    if project.question_count.present? && project.question_count > 0
      # Custom question count specified
      total_questions = project.question_count
    elsif project.interview_length.present?
      # Use predefined lengths
      total_questions = case project.interview_length
                       when '5_minutes'
                         5
                       when '10_minutes'
                         10
                       when '20_minutes'
                         20
                       when 'unlimited'
                         40 # Initial batch for unlimited
                       else
                         10 # Default to 10 minutes
                       end
    else
      # Default to 10 questions if nothing specified
      total_questions = 10
    end
    
    # For now, structure as 1 chapter with 1 section containing all questions
    # This can be enhanced later to distribute questions across multiple chapters/sections
    {
      num_chapters: 1,
      sections_per_chapter: 1,
      questions_per_section: total_questions
    }
  end
end