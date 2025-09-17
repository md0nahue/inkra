class Api::InterviewQuestionsController < Api::BaseController

  # Generate a complete interview outline
  def generate_outline
    Rails.logger.info "[INTERVIEW_DEBUG] generate_outline called with params: #{params.inspect}"
    topic = params[:topic]
    options = {
      num_chapters: params[:num_chapters]&.to_i || 3,
      sections_per_chapter: params[:sections_per_chapter]&.to_i || 2,
      questions_per_section: params[:questions_per_section]&.to_i || 3
    }
    Rails.logger.info "[INTERVIEW_DEBUG] Parsed options: #{options.inspect}"

    if topic.blank?
      Rails.logger.warn "[INTERVIEW_DEBUG] Topic is blank, returning bad_request"
      render json: { error: 'Topic is required' }, status: :bad_request
      return
    end

    begin
      Rails.logger.info "[INTERVIEW_DEBUG] Creating InterviewQuestionService instance"
      service = InterviewQuestionService.new
      Rails.logger.info "[INTERVIEW_DEBUG] Calling generate_interview_outline with topic: #{topic}, options: #{options}"
      outline = service.generate_interview_outline(topic, options)
      Rails.logger.info "[INTERVIEW_DEBUG] Outline generated: #{outline.keys.inspect}, chapters count: #{outline[:chapters]&.size || 0}"

      if outline[:error]
        Rails.logger.error "[INTERVIEW_DEBUG] Outline generation error: #{outline[:error]}"
        render json: { error: outline[:error] }, status: :unprocessable_entity
      else
        response_data = {
          outline: outline,
          generated_at: Time.current.iso8601
        }
        Rails.logger.info "[INTERVIEW_DEBUG] Successful outline generation, returning: #{response_data.keys.inspect}"
        render json: response_data
      end
    rescue => e
      Rails.logger.error "[INTERVIEW_DEBUG] Interview outline generation failed: #{e.message}"
      Rails.logger.error "[INTERVIEW_DEBUG] Backtrace: #{e.backtrace.first(5).join('\n')}"
      render json: { error: 'Failed to generate interview outline' }, status: :internal_server_error
    end
  end

  # Generate additional questions for a section
  def generate_section_questions
    Rails.logger.info "[INTERVIEW_DEBUG] generate_section_questions called with params: #{params.inspect}"
    section_id = params[:section_id]
    num_questions = params[:num_questions]&.to_i || 3
    Rails.logger.info "[INTERVIEW_DEBUG] Looking for section_id: #{section_id}, num_questions: #{num_questions}"

    section = current_user.projects.joins(:sections).find_by(sections: { id: section_id })&.sections&.find(section_id)
    unless section
      Rails.logger.warn "[INTERVIEW_DEBUG] Section not found for id: #{section_id}, user: #{current_user.id}"
      render json: { error: 'Section not found' }, status: :not_found
      return
    end
    Rails.logger.info "[INTERVIEW_DEBUG] Found section: #{section.title}, chapter: #{section.chapter.title}"

    begin
      service = InterviewQuestionService.new
      section_context = {
        chapter_title: section.chapter.title,
        section_title: section.title,
        existing_questions: section.questions.by_order.pluck(:text)
      }
      Rails.logger.info "[INTERVIEW_DEBUG] Section context: #{section_context.inspect}"

      Rails.logger.info "[INTERVIEW_DEBUG] Generating #{num_questions} new questions"
      new_questions = service.generate_section_questions(section_context, num_questions)
      Rails.logger.info "[INTERVIEW_DEBUG] Generated #{new_questions.size} questions"

      response_data = {
        section_id: section.id,
        new_questions: new_questions,
        generated_at: Time.current.iso8601
      }
      Rails.logger.info "[INTERVIEW_DEBUG] Returning new questions for section #{section_id}"
      render json: response_data
    rescue => e
      Rails.logger.error "[INTERVIEW_DEBUG] Section questions generation failed: #{e.message}"
      Rails.logger.error "[INTERVIEW_DEBUG] Backtrace: #{e.backtrace.first(5).join('\n')}"
      render json: { error: 'Failed to generate section questions' }, status: :internal_server_error
    end
  end

  # Refine existing questions based on feedback
  def refine_questions
    question_ids = params[:question_ids] || []
    feedback = params[:feedback]

    if question_ids.empty? || feedback.blank?
      render json: { error: 'Question IDs and feedback are required' }, status: :bad_request
      return
    end

    questions = current_user.projects.joins(:questions).where(questions: { id: question_ids }).distinct.flat_map(&:questions).select { |q| question_ids.include?(q.id) }
    if questions.empty?
      render json: { error: 'No questions found' }, status: :not_found
      return
    end

    begin
      service = InterviewQuestionService.new
      questions_data = questions.map { |q| { text: q.text, id: q.id } }
      
      refined_questions = service.refine_questions(questions_data, feedback)

      render json: {
        original_questions: questions_data,
        refined_questions: refined_questions,
        feedback_applied: feedback,
        generated_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Question refinement failed: #{e.message}"
      render json: { error: 'Failed to refine questions' }, status: :internal_server_error
    end
  end

  # Create project from generated outline
  def create_project_from_outline
    Rails.logger.info "[INTERVIEW_DEBUG] create_project_from_outline called"
    project_title = params[:title]
    topic = params[:topic]
    outline_data = params[:outline]
    Rails.logger.info "[INTERVIEW_DEBUG] Project params - title: #{project_title}, topic: #{topic}, outline keys: #{outline_data&.keys&.inspect}"

    if project_title.blank? || topic.blank? || outline_data.blank?
      Rails.logger.warn "[INTERVIEW_DEBUG] Missing required params - title: #{project_title.present?}, topic: #{topic.present?}, outline: #{outline_data.present?}"
      render json: { error: 'Title, topic, and outline are required' }, status: :bad_request
      return
    end

    begin
      ActiveRecord::Base.transaction do
        Rails.logger.info "[INTERVIEW_DEBUG] Starting transaction to create project"
        # Create the project
        project = current_user.projects.create!(
          title: project_title,
          topic: topic,
          status: 'outline_ready'
        )
        Rails.logger.info "[INTERVIEW_DEBUG] Created project id: #{project.id}, title: #{project.title}"

        # Create chapters, sections, and questions from outline
        chapters_count = outline_data[:chapters]&.size || 0
        Rails.logger.info "[INTERVIEW_DEBUG] Creating #{chapters_count} chapters"
        
        outline_data[:chapters]&.each do |chapter_data|
          chapter = project.chapters.create!(
            title: chapter_data[:title],
            order: chapter_data[:order],
            omitted: false
          )
          Rails.logger.info "[INTERVIEW_DEBUG] Created chapter id: #{chapter.id}, title: #{chapter.title}, order: #{chapter.order}"

          sections_count = chapter_data[:sections]&.size || 0
          Rails.logger.info "[INTERVIEW_DEBUG] Creating #{sections_count} sections for chapter #{chapter.id}"
          
          chapter_data[:sections]&.each do |section_data|
            section = chapter.sections.create!(
              title: section_data[:title],
              order: section_data[:order],
              omitted: false
            )
            Rails.logger.info "[INTERVIEW_DEBUG] Created section id: #{section.id}, title: #{section.title}, order: #{section.order}"

            questions_count = section_data[:questions]&.size || 0
            Rails.logger.info "[INTERVIEW_DEBUG] Creating #{questions_count} questions for section #{section.id}"
            
            section_data[:questions]&.each do |question_data|
              question = section.questions.create!(
                text: question_data[:text],
                order: question_data[:order]
              )
              Rails.logger.info "[INTERVIEW_DEBUG] Created question id: #{question.id}, order: #{question.order}"
            end
          end
        end
        
        Rails.logger.info "[INTERVIEW_DEBUG] Project creation complete - total questions: #{project.questions.count}"

        render json: {
          project_id: project.id,
          title: project.title,
          status: project.status,
          created_at: project.created_at.iso8601,
          message: 'Project created successfully from generated outline'
        }, status: :created
      end
    rescue => e
      Rails.logger.error "[INTERVIEW_DEBUG] Project creation from outline failed: #{e.message}"
      Rails.logger.error "[INTERVIEW_DEBUG] Error class: #{e.class.name}"
      Rails.logger.error "[INTERVIEW_DEBUG] Backtrace: #{e.backtrace.first(5).join('\n')}"
      render json: { error: 'Failed to create project from outline' }, status: :internal_server_error
    end
  end

  # Generate interview from tracker data
  def generate_from_tracker
    Rails.logger.info "[INTERVIEW_DEBUG] generate_from_tracker called with params: #{params.inspect}"
    tracker_name = params[:tracker_name]
    tracker_context = params[:tracker_context]
    Rails.logger.info "[INTERVIEW_DEBUG] Tracker: #{tracker_name}, context keys: #{tracker_context&.keys&.inspect if tracker_context.is_a?(Hash)}"

    if tracker_name.blank? || tracker_context.blank?
      Rails.logger.warn "[INTERVIEW_DEBUG] Missing tracker params - name: #{tracker_name.present?}, context: #{tracker_context.present?}"
      render json: { error: 'Tracker name and context are required' }, status: :bad_request
      return
    end

    begin
      Rails.logger.info "[INTERVIEW_DEBUG] Creating InterviewQuestionService for tracker generation"
      service = InterviewQuestionService.new
      Rails.logger.info "[INTERVIEW_DEBUG] Calling generate_interview_from_tracker"
      outline = service.generate_interview_from_tracker(tracker_name, tracker_context)
      Rails.logger.info "[INTERVIEW_DEBUG] Tracker outline generated, keys: #{outline.keys.inspect}"

      if outline[:error]
        Rails.logger.error "[INTERVIEW_DEBUG] Tracker generation error: #{outline[:error]}"
        render json: { error: outline[:error] }, status: :unprocessable_entity
      else
        response_data = {
          outline: outline,
          tracker_name: tracker_name,
          generated_at: Time.current.iso8601
        }
        Rails.logger.info "[INTERVIEW_DEBUG] Successful tracker interview generation"
        render json: response_data
      end
    rescue => e
      Rails.logger.error "[INTERVIEW_DEBUG] Tracker interview generation failed: #{e.message}"
      Rails.logger.error "[INTERVIEW_DEBUG] Backtrace: #{e.backtrace.first(5).join('\n')}"
      render json: { error: 'Failed to generate interview from tracker data' }, status: :internal_server_error
    end
  end

  # Add generated questions to existing section
  def add_questions_to_section
    section_id = params[:section_id]
    questions_data = params[:questions] || []

    section = current_user.projects.joins(:sections).find_by(sections: { id: section_id })&.sections&.find(section_id)
    unless section
      render json: { error: 'Section not found' }, status: :not_found
      return
    end

    if questions_data.empty?
      render json: { error: 'Questions data is required' }, status: :bad_request
      return
    end

    begin
      ActiveRecord::Base.transaction do
        max_order = section.questions.maximum(:order) || 0

        new_questions = questions_data.map.with_index do |question_data, index|
          section.questions.create!(
            text: question_data[:text],
            order: max_order + index + 1
          )
        end

        render json: {
          section_id: section.id,
          added_questions: new_questions.map do |q|
            {
              question_id: q.id,
              text: q.text,
              order: q.order
            }
          end,
          message: "#{new_questions.count} questions added successfully"
        }
      end
    rescue => e
      Rails.logger.error "Adding questions to section failed: #{e.message}"
      render json: { error: 'Failed to add questions to section' }, status: :internal_server_error
    end
  end
end