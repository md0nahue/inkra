class UnlimitedQuestionsGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(project_id)
    Rails.logger.info "UnlimitedQuestionsGenerationJob: Starting for project #{project_id}"
    
    project = Project.find_by(id: project_id)
    unless project
      Rails.logger.warn "UnlimitedQuestionsGenerationJob: Project #{project_id} not found"
      return
    end
    
    # Only process if this is an unlimited interview
    unless project.interview_length == 'unlimited'
      Rails.logger.info "UnlimitedQuestionsGenerationJob: Project #{project_id} is not unlimited mode, skipping"
      return
    end
    
    # Count total questions and answered questions
    total_questions = project.questions.where(is_follow_up: false).count
    answered_questions = AudioSegment
      .where(project_id: project.id)
      .where.not(question_id: nil)
      .distinct
      .count(:question_id)
    
    Rails.logger.info "UnlimitedQuestionsGenerationJob: Project #{project_id} has #{answered_questions}/#{total_questions} questions answered"
    
    # Check if we've reached the 2/3 threshold
    threshold = (total_questions * 2.0 / 3.0).ceil
    
    if answered_questions >= threshold
      Rails.logger.info "UnlimitedQuestionsGenerationJob: Threshold reached (#{answered_questions} >= #{threshold}), generating more questions"
      
      # Generate additional questions
      generate_additional_questions(project)
    else
      Rails.logger.info "UnlimitedQuestionsGenerationJob: Threshold not reached yet (#{answered_questions} < #{threshold})"
    end
  end
  
  private
  
  def generate_additional_questions(project)
    begin
      # Get existing questions for context
      existing_questions = project.questions
        .where(is_follow_up: false)
        .order(:order)
        .pluck(:text)
      
      # Get answered questions with their responses for better context
      answered_segments = AudioSegment
        .joins(:question)
        .where(project_id: project.id)
        .where.not(question_id: nil)
        .select('questions.text as question_text, audio_segments.transcript')
      
      context = {
        topic: project.topic,
        existing_questions: existing_questions,
        answered_questions: answered_segments.map { |s| { question: s.question_text, answer: s.transcript } }
      }
      
      Rails.logger.info "UnlimitedQuestionsGenerationJob: Generating 20 additional questions with context"
      
      # Use the interview question service to generate more questions
      service = InterviewQuestionService.new
      new_questions_data = service.generate_additional_questions_for_unlimited(context, 20)
      
      if new_questions_data.present?
        # Find the last section to add questions to
        last_section = project.sections.joins(:chapter).order('chapters.order DESC, sections.order DESC').first
        
        if last_section
          # Get the highest order number for existing questions
          max_order = project.questions.maximum(:order) || 0
          
          ActiveRecord::Base.transaction do
            new_questions_data.each_with_index do |question_text, index|
              question = last_section.questions.create!(
                text: question_text,
                order: max_order + index + 1,
                is_follow_up: false
              )
              
              # If speech interview, generate audio
              if project.is_speech_interview
                PollyGenerationJob.perform_later(
                  question.id,
                  voice_id: project.voice_id || 'Joanna',
                  speech_rate: project.speech_rate || 100
                )
              end
            end
          end
          
          Rails.logger.info "UnlimitedQuestionsGenerationJob: Successfully added #{new_questions_data.length} new questions to project #{project.id}"
        else
          Rails.logger.error "UnlimitedQuestionsGenerationJob: No section found to add questions to"
        end
      else
        Rails.logger.error "UnlimitedQuestionsGenerationJob: Failed to generate additional questions"
      end
    rescue => e
      Rails.logger.error "UnlimitedQuestionsGenerationJob: Error generating questions: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end