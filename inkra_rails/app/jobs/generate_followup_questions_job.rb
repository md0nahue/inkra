class GenerateFollowupQuestionsJob < ApplicationJob
  queue_as :default

  def perform(audio_segment_id)
    Rails.logger.info "🔍 GenerateFollowupQuestionsJob: Starting with audio_segment_id: #{audio_segment_id}"
    
    # Eager load associations to prevent N+1 queries
    audio_segment = AudioSegment.includes(question: { section: { chapter: :project } }).find_by(id: audio_segment_id)
    unless audio_segment
      Rails.logger.warn "GenerateFollowupQuestionsJob: AudioSegment with id #{audio_segment_id} not found, skipping job"
      return
    end
    Rails.logger.info "🔍 Found audio_segment: #{audio_segment.inspect}"
    Rails.logger.info "🔍 Question present: #{audio_segment.question.present?}, Transcription present: #{audio_segment.transcription_text.present?}"
    
    return unless audio_segment.question.present? && audio_segment.transcription_text.present?

    # 1. Generate questions via Gemini
    Rails.logger.info "🔍 Generating followup questions for question: #{audio_segment.question.text}"
    service = InterviewQuestionService.new
    new_questions_data = service.generate_followup_questions(
      original_question_text: audio_segment.question.text,
      user_answer: audio_segment.transcription_text
    )

    Rails.logger.info "🔍 Generated questions data: #{new_questions_data.inspect}"
    return if new_questions_data.blank?

    # 2. Persist new questions
    new_questions = persist_followup_questions(audio_segment.question, new_questions_data)
    Rails.logger.info "🔍 Persisted #{new_questions.count} new questions: #{new_questions.map(&:text).inspect}"

    # 3. Questions saved - no real-time broadcasting needed with polling approach
    project = audio_segment.question.section.chapter.project
    Rails.logger.info "🔍 Follow-up questions saved for project #{project.id}."
  end

  private


  def persist_followup_questions(parent_question, questions_data)
    new_questions = []
    new_question_ids = []
    
    ActiveRecord::Base.transaction do
      # Get all questions in the section to find the next available order
      section = parent_question.section
      max_order_in_section = section.questions.maximum(:order) || 0
      
      # Also check existing follow-ups for the parent to ensure we don't duplicate orders
      existing_followup_count = parent_question.follow_up_questions.count
      
      # Start ordering after the highest order in the section
      # This ensures followup questions always come after existing questions
      base_order = [max_order_in_section + 1, parent_question.order + existing_followup_count + 1].max
      
      new_questions = questions_data.map.with_index do |q_data, index|
        question = parent_question.follow_up_questions.create!(
          section: parent_question.section,
          text: q_data[:text],
          order: base_order + index,
          is_follow_up: true
        )
        new_question_ids << question.id
        question
      end
    end
    
    # Enqueue Polly jobs after transaction commits for speech interviews
    project = parent_question.section.chapter.project
    if project.is_speech_interview && new_question_ids.any?
      Rails.logger.info "Enqueueing Polly jobs for #{new_question_ids.length} follow-up questions"
      new_question_ids.each do |question_id|
        PollyGenerationJob.perform_later(
          question_id,
          voice_id: project.voice_id || 'Joanna',
          speech_rate: project.speech_rate || 100
        )
      end
    end
    
    new_questions
  end

end
