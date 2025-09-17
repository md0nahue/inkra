class Api::ProjectsController < Api::BaseController
  include ErrorResponder
  
  before_action :set_project, except: [:index, :recent, :create]

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def index
    # Optimize with eager loading and single query with aggregations (presets removed)
    projects = current_user.projects
                          .left_joins(:chapters, :sections, :questions)
                          .select('projects.*, 
                                  COUNT(DISTINCT chapters.id) as chapters_count,
                                  COUNT(DISTINCT sections.id) as sections_count,
                                  COUNT(DISTINCT questions.id) as questions_count,
                                  COUNT(DISTINCT CASE WHEN questions.is_follow_up = false THEN questions.id END) as base_questions_count,
                                  COUNT(DISTINCT CASE WHEN questions.is_follow_up = true THEN questions.id END) as followup_questions_count')
                          .group('projects.id')
                          .order('last_accessed_at DESC NULLS LAST, last_modified_at DESC')
    
    # Get answered questions count for all projects in a single query
    answered_counts = AudioSegment
      .where(project_id: projects.map(&:id))
      .where.not(question_id: nil)
      .group(:project_id)
      .distinct
      .count(:question_id)
    
    render json: {
      projects: projects.map do |project|
        # Calculate outline status without additional queries
        outline_status = case project.status
                        when 'outline_generating'
                          'generating'
                        when 'failed'
                          'failed'
                        else
                          project.chapters_count > 0 ? 'ready' : 'not_started'
                        end
        
        {
          id: project.id,
          title: project.title,
          topic: project.topic,
          created_at: project.created_at.iso8601,
          last_modified_at: project.last_modified_at.iso8601,
          last_accessed_at: project.last_accessed_at&.iso8601,
          is_speech_interview: project.is_speech_interview,
          outline: {
            status: outline_status,
            chapters_count: project.chapters_count,
            sections_count: project.sections_count,
            questions_count: project.questions_count,
            base_questions_count: project.base_questions_count || 0,
            followup_questions_count: project.followup_questions_count || 0,
            answered_questions_count: answered_counts[project.id] || 0
          }
        }
      end
    }
  end

  # Test Harness Status: ✅ Batch endpoint for recent projects
  def recent
    limit = params[:limit]&.to_i || 5
    offset = params[:offset]&.to_i || 0
    
    # Get recent projects with counts, limited by parameters
    projects = current_user.projects
                          .left_joins(:chapters, :sections, :questions)
                          .select('projects.*, 
                                  COUNT(DISTINCT chapters.id) as chapters_count,
                                  COUNT(DISTINCT sections.id) as sections_count,
                                  COUNT(DISTINCT questions.id) as questions_count,
                                  COUNT(DISTINCT CASE WHEN questions.is_follow_up = false THEN questions.id END) as base_questions_count,
                                  COUNT(DISTINCT CASE WHEN questions.is_follow_up = true THEN questions.id END) as followup_questions_count')
                          .group('projects.id')
                          .order('last_accessed_at DESC NULLS LAST, last_modified_at DESC')
                          .limit(limit)
                          .offset(offset)
    
    # Get total count for pagination
    total_count = current_user.projects.count
    has_more = offset + limit < total_count
    
    # Get answered questions count for these projects
    answered_counts = AudioSegment
      .where(project_id: projects.map(&:id))
      .where.not(question_id: nil)
      .group(:project_id)
      .distinct
      .count(:question_id)
    
    render json: {
      projects: projects.map do |project|
        outline_status = case project.status
                        when 'outline_generating'
                          'generating'
                        when 'failed'
                          'failed'
                        else
                          project.chapters_count > 0 ? 'ready' : 'not_started'
                        end
        
        {
          id: project.id,
          title: project.title,
          topic: project.topic,
          created_at: project.created_at.iso8601,
          last_modified_at: project.last_modified_at.iso8601,
          last_accessed_at: project.last_accessed_at&.iso8601,
          is_speech_interview: project.is_speech_interview,
          outline: {
            status: outline_status,
            chapters_count: project.chapters_count,
            sections_count: project.sections_count,
            questions_count: project.questions_count,
            base_questions_count: project.base_questions_count || 0,
            followup_questions_count: project.followup_questions_count || 0,
            answered_questions_count: answered_counts[project.id] || 0
          }
        }
      end,
      pagination: {
        total_count: total_count,
        has_more: has_more,
        current_offset: offset,
        current_limit: limit
      }
    }
  end

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def create
    Rails.logger.debug "=== PROJECT CREATE DEBUG ==="
    Rails.logger.debug "Raw params: #{params.inspect}"
    Rails.logger.debug "Processed project_params: #{project_params.inspect}"
    
    # Implement retry logic with exponential backoff for race conditions
    max_retries = 3
    retry_count = 0
    
    begin
      retry_count += 1
      project = current_user.projects.new(project_params)

      ActiveRecord::Base.transaction do
        # Check for duplicate projects within the transaction to avoid race conditions
        topic = project_params[:topic]
        if topic.present?
          # Use advisory lock based on user_id + topic hash to prevent race conditions
          topic_hash = Digest::SHA256.hexdigest("#{current_user.id}_#{topic}").to_i(16) % 2147483647
          Rails.logger.debug "Acquiring advisory lock for user #{current_user.id}, topic: '#{topic}' (hash: #{topic_hash})"
          
          # Get advisory lock - this will block other requests with same user+topic combination
          ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{topic_hash})")
          
          # Now check for duplicates after acquiring the lock
          recent_duplicate = current_user.projects
                                        .where("created_at > ? AND topic = ?", 10.seconds.ago, topic)
                                        .first
          
          if recent_duplicate
            Rails.logger.warn "Duplicate project creation detected for topic '#{topic}' - returning existing project #{recent_duplicate.id}"
            return render json: {
              project_id: recent_duplicate.id,
              title: recent_duplicate.title,
              created_at: recent_duplicate.created_at.iso8601,
              duplicate_prevented: true
            }, status: :created
          end
        end
        # Preset functionality disabled - use custom topic only
        if project.title.blank? && project.topic.present?
          # If only topic is provided (from initial_topic), use it as both title and topic
          project.title = project.topic
        elsif project.topic.blank?
          project.topic = "Custom Interview" # Default fallback
          project.title = project.topic if project.title.blank?
        end

        project.status = 'outline_generating' # Initial status before scaffolding
        project.save!

        # CRITICAL FIX: Make outline generation asynchronous to avoid 20+ second API response times
        # Queue a background job to generate the outline instead of doing it synchronously
        Rails.logger.debug "Enqueuing async outline generation job for project #{project.id}"
        OutlineGenerationJob.perform_later(project.id)
      end

      # NOTE: Polly jobs will be enqueued by the OutlineGenerationJob after questions are created

      render json: {
        project_id: project.id,
        title: project.title,
        created_at: project.created_at.iso8601
      }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      render_error(e.record.errors.full_messages.join(", "), "VALIDATION_ERROR", :unprocessable_entity, { field_errors: e.record.errors.as_json })
    rescue PG::TRSerializationFailure, ActiveRecord::Deadlocked => e
      if retry_count < max_retries
        Rails.logger.warn "Transaction conflict on project creation attempt #{retry_count}, retrying... (#{e.class}: #{e.message})"
        sleep(0.1 * retry_count) # Exponential backoff: 0.1s, 0.2s, 0.3s
        retry
      else
        Rails.logger.error "Failed to create project after #{max_retries} retries due to transaction conflicts"
        render_error("Project creation failed due to high concurrency. Please try again.", "CREATION_CONFLICT", :service_unavailable)
      end
    rescue => e
      Rails.logger.error "Unexpected error in project creation: #{e.class}: #{e.message}"
      render_error("An unexpected error occurred during project creation", "INTERNAL_ERROR", :internal_server_error)
    end
  end

  def show
    # Touch last accessed timestamp
    @project.touch_accessed
    
    # Use a single optimized query to load all associations including follow_up_questions
    project_with_details = current_user.projects
      .includes(
        chapters: { 
          sections: {
            questions: :follow_up_questions
          }
        }
      )
      .where(id: @project.id)
      .first
    
    render json: project_json_representation(project_with_details)
  end
  

  def update
    Rails.logger.debug "=== PROJECT UPDATE DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Update params: #{params.inspect}"
    
    if params[:status]
      valid_statuses = ['outline_ready', 'recording_in_progress', 'transcribing', 'completed']
      unless valid_statuses.include?(params[:status])
        return render_error(
          "Invalid status: #{params[:status]}",
          "INVALID_STATUS",
          :bad_request
        )
      end
      
      @project.update!(
        status: params[:status],
        last_modified_at: Time.current
      )
    end
    
    # FIX: Eager load associations and render the full project object
    # to match the Swift client's expectation.
    project_with_details = current_user.projects
      .includes(
        chapters: { 
          sections: {
            questions: :follow_up_questions
          }
        }
      )
      .find(@project.id)
    
    render json: project_json_representation(project_with_details)
    
  rescue => e
    Rails.logger.error "Project update failed: #{e.class}: #{e.message}"
    render_error(
      "Failed to update project: #{e.message}",
      "UPDATE_ERROR",
      :internal_server_error
    )
  end

  def outline
    updates = params[:updates] || []
    
    updates.each do |update|
      if update[:chapter_id]
        chapter = @project.chapters.find(update[:chapter_id])
        chapter.update(omitted: update[:omitted]) if chapter
      elsif update[:section_id]
        section = @project.sections.find(update[:section_id])
        section.update(omitted: update[:omitted]) if section
      elsif update[:question_id]
        question = @project.questions.find(update[:question_id])
        question.update(omitted: update[:omitted]) if question
      end
    end
    
    @project.update(last_modified_at: Time.current)
    
    render json: {
      message: 'Outline updated successfully',
      project_id: @project.id,
      status: @project.status
    }
  end

  def transcript
    if request.patch?
      update_transcript
    else
      show_transcript
    end
  end

  private

  def show_transcript
    transcript = @project.transcript
    
    # Create a placeholder transcript if it doesn't exist
    unless transcript
      transcript = @project.build_transcript
      transcript.status = 'processing_raw'
      transcript.save!
    end
    
    render json: {
      id: transcript.id,
      project_id: @project.id,
      status: transcript.status,
      last_updated: transcript.last_updated&.iso8601,
      raw_content: transcript.raw_content,
      polished_content: transcript.polished_content,
      edited_content: transcript.edited_content_json || [],
      raw_structured_content: transcript.raw_structured_content_json || []
    }
  end

  def update_transcript
    transcript = @project.transcript
    
    unless transcript
      render_error("Transcript not found", "TRANSCRIPT_NOT_FOUND", :not_found)
      return
    end
    
    # Extract polished content from request
    polished_content = params[:polishedContent]
    edited_content = params[:editedContent]
    
    begin
      # Update transcript
      transcript.update!(
        polished_content: polished_content,
        edited_content_json: edited_content,
        last_updated: Time.current
      )
      
      # Update project's last modified timestamp
      @project.update!(last_modified_at: Time.current)
      
      Rails.logger.info "Transcript updated for project #{@project.id}"
      
      render json: {
        id: transcript.id,
        project_id: @project.id,
        status: transcript.status,
        last_updated: transcript.last_updated.iso8601,
        message: "Transcript updated successfully"
      }
      
    rescue => e
      Rails.logger.error "Failed to update transcript for project #{@project.id}: #{e.message}"
      render_error("Failed to update transcript", "UPDATE_FAILED", :unprocessable_entity)
    end
  end

  public

  def add_more_chapters
    Rails.logger.debug "=== ADD_MORE_CHAPTERS DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Project topic: #{@project.topic}"
    Rails.logger.debug "Current chapters count: #{@project.chapters.count}"
    
    begin
      # Use LLM service to generate additional chapters
      service = InterviewQuestionService.new
      Rails.logger.debug "InterviewQuestionService instantiated"
      
      additional_outline = service.generate_additional_chapters(@project)
      Rails.logger.debug "LLM service returned: #{additional_outline.inspect}"
      
      if additional_outline[:error]
        Rails.logger.error "Additional chapters generation failed: #{additional_outline[:error]}"
        render_error(
          "Failed to generate additional chapters: #{additional_outline[:error]}",
          "GENERATION_ERROR",
          :unprocessable_entity
        )
        return
      end
      
      # Create new chapters, sections, and questions from LLM-generated outline
      Rails.logger.debug "Creating additional chapters from outline..."
      Rails.logger.debug "New chapters count: #{additional_outline[:chapters]&.length || 0}"
      
      created_chapters = []
      new_question_ids = []
      
      ActiveRecord::Base.transaction do
        additional_outline[:chapters]&.each do |chapter_data|
          Rails.logger.debug "Creating chapter: #{chapter_data[:title]}"
          chapter = @project.chapters.create!(
            title: chapter_data[:title],
            order: chapter_data[:order],
            omitted: false
          )
          Rails.logger.debug "Chapter created with ID: #{chapter.id}"
          
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
              if @project.is_speech_interview
                new_question_ids << question.id
              end
            end
          end
        
          created_chapters << {
            chapter_id: chapter.id,
            title: chapter.title,
            order: chapter.order,
            omitted: chapter.omitted,
            sections: chapter.sections.by_order.map do |section|
              {
                section_id: section.id,
                title: section.title,
                order: section.order,
                omitted: section.omitted,
                questions: section.questions.base_questions.by_order.map do |question|
                  {
                    question_id: question.id,
                    text: question.text,
                    order: question.order,
                    omitted: question.omitted,
                    is_follow_up: question.is_follow_up
                  }
                end
              }
            end
          }
        end
      end
      
      # Enqueue Polly jobs after transaction commits to ensure questions exist
      if @project.is_speech_interview && new_question_ids.any?
        Rails.logger.debug "Enqueueing Polly jobs for #{new_question_ids.length} questions"
        new_question_ids.each do |question_id|
          PollyGenerationJob.perform_later(
            question_id,
            voice_id: @project.voice_id || 'Joanna',
            speech_rate: @project.speech_rate || 100
          )
        end
      end
      
      Rails.logger.debug "Updating project last_modified_at"
      @project.update!(last_modified_at: Time.current)
      Rails.logger.debug "Additional chapters generation completed successfully"
      
      render json: {
        message: 'Additional chapters generated successfully',
        project_id: @project.id,
        new_chapters: created_chapters,
        total_chapters_count: @project.chapters.count
      }
    rescue => e
      Rails.logger.error "Additional chapters generation failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to generate additional chapters: #{e.message}",
        "GENERATION_ERROR",
        :internal_server_error
      )
    end
  end

  def complete_interview
    Rails.logger.debug "=== COMPLETE_INTERVIEW DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Current status: #{@project.status}"
    
    # Validate that the project is in the right state to be completed
    unless ['outline_ready', 'recording_in_progress'].include?(@project.status)
      render_error(
        "Cannot complete interview for project with status: #{@project.status}",
        "INVALID_STATUS",
        :unprocessable_entity
      )
      return
    end
    
    begin
      # Update project status to transcribing (will later become completed when transcript is ready)
      @project.update!(
        status: 'transcribing',
        last_modified_at: Time.current
      )
      
      Rails.logger.debug "Project status updated to transcribing"
      
      # Check if there are any audio segments to process
      audio_segments_count = @project.audio_segments.count
      
      # If no audio segments, mark as completed immediately
      if audio_segments_count == 0
        @project.update!(status: 'completed')
        Rails.logger.debug "No audio segments found, marking as completed"
      else
        # Generate complete transcript for the entire interview
        Rails.logger.debug "Generating complete transcript for #{audio_segments_count} audio segments"
        TranscriptContentAssemblerService.generate_complete_transcript(@project.id)
      end
      
      render json: {
        message: 'Interview completed successfully',
        project_id: @project.id,
        status: @project.status,
        next_step: audio_segments_count > 0 ? 'transcribing' : 'view_transcript',
        completed_at: Time.current.iso8601,
        audio_segments_count: audio_segments_count
      }
    rescue => e
      Rails.logger.error "Interview completion failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to complete interview: #{e.message}",
        "COMPLETION_ERROR",
        :internal_server_error
      )
    end
  end

  # Get available questions for interview including existing followup questions
  def available_questions
    Rails.logger.debug "=== AVAILABLE_QUESTIONS DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Current status: #{@project.status}"
    
    begin
      
      # Use InterviewFlowService to generate the proper question queue
      # This includes both base questions and any existing followup questions
      service = InterviewFlowService.new(@project)
      question_queue = service.generate_question_queue
      
      Rails.logger.debug "Generated question queue with #{question_queue.length} questions"
      
      # CRITICAL FIX: Filter questions based on audio readiness for speech interviews
      # For speech interviews: Only include questions that have audio ready
      # For reading interviews: Include all questions immediately
      initial_count = question_queue.length
      question_queue = question_queue.select do |question|
        question.available_for_project_type?(@project.is_speech_interview)
      end
      
      if @project.is_speech_interview && question_queue.length < initial_count
        filtered_count = initial_count - question_queue.length
        Rails.logger.debug "Speech interview: Filtered out #{filtered_count} questions without completed audio"
        Rails.logger.debug "Remaining questions: #{question_queue.length}/#{initial_count}"
      end
      
      # Serialize the questions in the format expected by the iOS client
      Rails.logger.debug "\n🎵🔍 AUDIO URL MAPPING DEBUG - available_questions endpoint"
      Rails.logger.debug "━" * 50
      
      serialized_questions = question_queue.map do |question|
        question_data = {
          question_id: question.id,
          text: question.text,
          order: question.order,
          omitted: question.omitted,
          skipped: question.skipped,
          parent_question_id: question.parent_question_id,
          is_follow_up: question.is_follow_up,
          section_id: question.section_id,
          section_title: question.section.title,
          chapter_id: question.section.chapter_id,
          chapter_title: question.section.chapter.title
        }
        
        # Include polly_audio_url if this is a speech interview
        # Since we already filtered for audio-ready questions, all speech interview questions should have audio
        if @project.is_speech_interview
          if question.polly_audio_clip
            audio_url = question.polly_audio_clip.s3_url
            question_data[:polly_audio_url] = audio_url
            
            # DEBUG: Log the audio mapping
            Rails.logger.debug "📌 Question #{question.id}: \"#{question.text[0..50]}...\""
            Rails.logger.debug "   🔗 S3 Key: #{question.polly_audio_clip.s3_key}"
            Rails.logger.debug "   🎙️ Voice: #{question.polly_audio_clip.voice_id}"
            Rails.logger.debug "   ⏱️ Rate: #{question.polly_audio_clip.speech_rate}"
            Rails.logger.debug "   📦 Status: #{question.polly_audio_clip.status}"
            Rails.logger.debug "   🔗 URL: #{audio_url[0..100]}..."
          else
            Rails.logger.warn "⚠️ Question #{question.id} has NO polly_audio_clip!"
          end
        end
        
        question_data
      end
      
      Rails.logger.debug "✅ Total questions with audio: #{serialized_questions.count { |q| q[:polly_audio_url].present? }}"
      Rails.logger.debug "━" * 50
      
      render json: {
        project_id: @project.id,
        status: @project.status,
        questions: serialized_questions,
        total_questions: question_queue.length,
        generated_at: Time.current.iso8601
      }
      
    rescue => e
      Rails.logger.error "Available questions request failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to get available questions: #{e.message}",
        "QUESTIONS_ERROR",
        :internal_server_error
      )
    end
  end

  def destroy
    project_id = @project.id
    title = @project.title
    @project.destroy
    render json: { message: "Project '#{title}' deleted successfully.", project_id: project_id }, status: :ok
  rescue => e
    render_error("Failed to delete project: #{e.message}", "DELETE_ERROR", :internal_server_error)
  end
  
  # Get follow-up questions created after a specific timestamp
  def follow_up_questions
    timestamp_param = params[:since]
    
    if timestamp_param.blank?
      render_error("Missing 'since' timestamp parameter", "MISSING_TIMESTAMP", :bad_request)
      return
    end
    
    begin
      since_timestamp = Time.parse(timestamp_param)
    rescue ArgumentError
      render_error("Invalid timestamp format", "INVALID_TIMESTAMP", :bad_request)
      return
    end
    
    # Get all questions in this project created after the timestamp
    new_questions = @project.questions
                           .where("questions.created_at > ?", since_timestamp)
                           .includes(:section => {:chapter => {}})
                           .order("questions.created_at")
    
    # Serialize the questions in the format expected by the iOS client
    serialized_questions = new_questions.map do |question|
      {
        question_id: question.id,
        text: question.text,
        order: question.order,
        omitted: question.omitted,
        parent_question_id: question.parent_question_id,
        is_follow_up: question.is_follow_up,
        section_id: question.section_id,
        section_title: question.section.title,
        chapter_id: question.section.chapter_id,
        chapter_title: question.section.chapter.title,
        created_at: question.created_at.iso8601
      }
    end
    
    render json: {
      project_id: @project.id,
      since: since_timestamp.iso8601,
      new_questions: serialized_questions,
      count: new_questions.count,
      generated_at: Time.current.iso8601
    }
    
  rescue => e
    Rails.logger.error "Follow-up questions request failed: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render_error(
      "Failed to get follow-up questions: #{e.message}",
      "FOLLOWUP_QUESTIONS_ERROR",
      :internal_server_error
    )
  end

  # Get questions with their actual interview responses
  def questions_with_responses
    Rails.logger.debug "=== QUESTIONS_WITH_RESPONSES DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Current status: #{@project.status}"
    
    begin
      # Get all questions with their associated audio segments (responses)
      questions_with_audio = @project.questions
                                    .includes(:section => {:chapter => {}}, :audio_segments => {})
                                    .order("sections.order, questions.order")
      
      Rails.logger.debug "Found #{questions_with_audio.count} questions total"
      
      # Serialize questions with their responses
      serialized_questions = questions_with_audio.map do |question|
        # Get the audio segment (response) for this question
        audio_response = question.audio_segments.first
        
        question_data = {
          question_id: question.id,
          text: question.text,
          order: question.order,
          omitted: question.omitted,
          skipped: question.skipped,
          parent_question_id: question.parent_question_id,
          is_follow_up: question.is_follow_up,
          section_id: question.section_id,
          section_title: question.section.title,
          chapter_id: question.section.chapter_id,
          chapter_title: question.section.chapter.title,
          # Add response data
          has_response: audio_response.present?,
          response_status: audio_response&.upload_status,
          transcribed_response: audio_response&.transcription_text,
          audio_file_name: audio_response&.file_name,
          response_duration: audio_response&.duration_seconds
        }
        
        # Include polly audio URL for speech interviews
        if @project.is_speech_interview && question.polly_audio_clip
          question_data[:polly_audio_url] = question.polly_audio_clip.s3_url
        end
        
        question_data
      end
      
      # Count questions with responses
      questions_with_responses = serialized_questions.count { |q| q[:has_response] }
      questions_with_transcriptions = serialized_questions.count { |q| q[:transcribed_response].present? }
      
      Rails.logger.debug "Questions with audio responses: #{questions_with_responses}"
      Rails.logger.debug "Questions with transcriptions: #{questions_with_transcriptions}"
      
      render json: {
        project_id: @project.id,
        project_title: @project.title,
        status: @project.status,
        questions: serialized_questions,
        total_questions: questions_with_audio.count,
        questions_with_responses: questions_with_responses,
        questions_with_transcriptions: questions_with_transcriptions,
        generated_at: Time.current.iso8601
      }
      
    rescue => e
      Rails.logger.error "Questions with responses request failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to get questions with responses: #{e.message}",
        "QUESTIONS_WITH_RESPONSES_ERROR",
        :internal_server_error
      )
    end
  end

  def generate_stock_image_topics
    begin
      selected_questions = params[:question_ids] || []
      
      if selected_questions.empty?
        return render_error(
          "No questions selected for stock image topic generation",
          "NO_QUESTIONS_SELECTED",
          :bad_request
        )
      end
      
      # Get transcription text from selected questions
      transcription_texts = []
      selected_questions.each do |question_id|
        audio_segment = @project.audio_segments.joins(:question).where(questions: { id: question_id }).first
        if audio_segment&.transcribed? && audio_segment.transcription_data
          text = audio_segment.transcription_data['text'] || audio_segment.transcription_data[:text]
          transcription_texts << text if text&.present?
        end
      end
      
      if transcription_texts.empty?
        return render_error(
          "No transcribed content found for selected questions",
          "NO_TRANSCRIPTION_DATA",
          :bad_request
        )
      end
      
      # Combine all transcription text
      combined_text = transcription_texts.join(' ')
      
      # Use Gemini to generate 5 stock image topics
      gemini_service = GeminiContentAnalysisService.new
      topics_result = gemini_service.generate_image_queries_for_text(
        combined_text,
        { type: "audiogram background selection", style: "stock photography" }
      )
      
      # Extract and format topics
      topics = topics_result.is_a?(Array) ? topics_result : (topics_result[:image_queries] || [])
      topics = topics.first(5) # Ensure we have exactly 5 topics
      
      # Pad with generic topics if needed
      while topics.length < 5
        generic_topics = ["professional workspace", "natural landscape", "urban architecture", "creative design", "inspiring scenery"]
        topics << generic_topics[topics.length % generic_topics.length]
      end
      
      render json: {
        project_id: @project.id,
        topics: topics.uniq.first(5),
        combined_text_preview: combined_text.truncate(200),
        generated_at: Time.current.iso8601
      }
      
    rescue => e
      Rails.logger.error "Stock image topic generation failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to generate stock image topics: #{e.message}",
        "TOPIC_GENERATION_ERROR",
        :internal_server_error
      )
    end
  end

  def fetch_stock_images
    begin
      topics = params[:topics] || []
      
      if topics.empty?
        return render_error(
          "No topics provided for stock image fetching",
          "NO_TOPICS_PROVIDED",
          :bad_request
        )
      end
      
      # Use ImageServiceBus to fetch images for each topic
      image_service = ImageServiceBus.new
      topic_images = {}
      
      topics.each do |topic|
        begin
          # Fetch 3 images per topic using stock_image category
          images_result = image_service.get_images(topic, 3, '1080p', 'stock_image')
          
          if images_result && images_result.any? && images_result.first[:images]
            topic_images[topic] = images_result.first[:images].map do |img|
              {
                url: img[:url],
                width: img[:width],
                height: img[:height],
                alt_text: img[:alt_text] || topic,
                source: img[:source] || 'stock'
              }
            end
          else
            topic_images[topic] = []
          end
          
        rescue => e
          Rails.logger.error "Failed to fetch images for topic '#{topic}': #{e.message}"
          topic_images[topic] = []
        end
      end
      
      render json: {
        project_id: @project.id,
        topic_images: topic_images,
        fetched_at: Time.current.iso8601
      }
      
    rescue => e
      Rails.logger.error "Stock image fetching failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error(
        "Failed to fetch stock images: #{e.message}",
        "IMAGE_FETCH_ERROR",
        :internal_server_error
      )
    end
  end

  def generate_audiogram_data
    begin
      selected_questions = params[:question_ids] || []
      
      if selected_questions.empty?
        return render_error(
          "No questions selected for audiogram",
          "NO_QUESTIONS_SELECTED",
          :bad_request
        )
      end
      
      # Generate audiogram data using the service
      audiogram_service = AudiogramGenerationService.new(
        project: @project,
        selected_questions: selected_questions,
        user: current_user
      )
      
      audiogram_data = audiogram_service.generate_audiogram_data
      
      if audiogram_data[:segments].empty?
        return render_error(
          "No valid audio segments found for selected questions",
          "NO_AUDIO_SEGMENTS",
          :bad_request
        )
      end
      
      # Generate ASS subtitle content
      subtitle_format = params[:subtitle_format]&.to_sym || :karaoke
      ass_content = audiogram_service.generate_ass_subtitle_content(
        audiogram_data, 
        output_format: subtitle_format
      )
      
      render json: {
        audiogram_data: audiogram_data,
        ass_subtitle_content: ass_content,
        metadata: {
          total_segments: audiogram_data[:segments].length,
          total_duration: audiogram_data[:total_duration],
          subtitle_format: subtitle_format,
          generated_at: Time.current.iso8601
        }
      }
      
    rescue => e
      Rails.logger.error "Audiogram generation failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render_error(
        "Failed to generate audiogram data: #{e.message}",
        "AUDIOGRAM_GENERATION_ERROR",
        :internal_server_error
      )
    end
  end

  # GET /api/projects/:id/questions/diff?since=<timestamp>
  # Returns only questions that are new or updated since the given timestamp
  # This is a lightweight endpoint for efficient background polling
  def questions_diff
    Rails.logger.debug "=== QUESTIONS_DIFF DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    
    # Parse the 'since' parameter
    since_param = params[:since]
    
    begin
      # Default to 1 minute ago if no timestamp provided
      since_time = since_param.present? ? Time.parse(since_param) : 1.minute.ago
      Rails.logger.debug "Fetching questions updated since: #{since_time.iso8601}"
      
      # Find questions that are new or updated since the timestamp
      # Include both base questions and follow-up questions
      new_questions = @project.questions
                              .where('questions.created_at > ? OR questions.updated_at > ?', since_time, since_time)
                              .includes(:section => :chapter)
                              .order(:order, :created_at)
      
      Rails.logger.debug "Found #{new_questions.count} new/updated questions"
      
      # Filter based on audio readiness for speech interviews
      if @project.is_speech_interview
        initial_count = new_questions.count
        new_questions = new_questions.select do |question|
          question.available_for_project_type?(true)
        end
        
        if new_questions.length < initial_count
          filtered_count = initial_count - new_questions.length
          Rails.logger.debug "Filtered out #{filtered_count} questions without audio"
        end
      end
      
      # Serialize the questions
      serialized_questions = new_questions.map do |question|
        question_data = {
          question_id: question.id,
          text: question.text,
          order: question.order,
          omitted: question.omitted,
          skipped: question.skipped,
          parent_question_id: question.parent_question_id,
          is_follow_up: question.is_follow_up,
          section_id: question.section_id,
          section_title: question.section&.title,
          chapter_id: question.section&.chapter_id,
          chapter_title: question.section&.chapter&.title,
          created_at: question.created_at.iso8601,
          updated_at: question.updated_at.iso8601
        }
        
        # Include audio URL for speech interviews
        if @project.is_speech_interview && question.polly_audio_clip
          audio_clip = question.polly_audio_clip
          if audio_clip.s3_key.present?
            question_data[:polly_audio_url] = audio_clip.s3_url
            Rails.logger.debug "Question #{question.id}: Added S3 audio URL"
          end
        end
        
        question_data
      end
      
      # Return the diff response
      render json: {
        project_id: @project.id,
        since: since_time.iso8601,
        current_time: Time.current.iso8601,
        new_questions_count: serialized_questions.length,
        questions: serialized_questions,
        has_more: false # Can be used to indicate if more questions are being generated
      }
      
    rescue ArgumentError => e
      Rails.logger.error "Invalid timestamp parameter: #{since_param}"
      render json: { 
        error: 'Invalid timestamp format', 
        message: 'Please provide timestamp in ISO 8601 format (e.g., 2025-01-01T12:00:00Z)' 
      }, status: :bad_request
    rescue => e
      Rails.logger.error "Questions diff failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Failed to fetch question diff' }, status: :internal_server_error
    end
  end

  # Update interview mode (speech vs reading)
  def interview_mode
    is_speech_interview = params[:is_speech_interview] || params[:isSpeechInterview]
    
    if is_speech_interview.nil?
      return render_error(
        "Missing required parameter: is_speech_interview", 
        "MISSING_PARAMETER", 
        :bad_request
      )
    end
    
    # Convert string to boolean if needed
    speech_enabled = case is_speech_interview
                    when true, 'true', '1', 1
                      true
                    when false, 'false', '0', 0
                      false
                    else
                      return render_error(
                        "Invalid value for is_speech_interview: must be true or false", 
                        "INVALID_PARAMETER", 
                        :bad_request
                      )
                    end

    @project.update!(is_speech_interview: speech_enabled)
    
    Rails.logger.info "Updated project #{@project.id} interview mode to #{speech_enabled ? 'speech' : 'reading'}"
    
    render json: {
      id: @project.id,
      is_speech_interview: @project.is_speech_interview,
      title: @project.title,
      topic: @project.topic,
      status: @project.status
    }
  end


  private

  def set_project
    @project = current_user.projects.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Project not found", "PROJECT_NOT_FOUND", :not_found)
  end

  def project_json_representation(project)
    # This logic is extracted from the `show` action for reusability.
    # Using `project.chapters` which should already be eager-loaded.
    # Use loaded associations to prevent additional queries
    chapters = project.chapters.to_a.sort_by(&:order)
    
    outline_status = case project.status
                     when 'outline_generating' then 'generating'
                     when 'failed' then 'failed'
                     else chapters.size > 0 ? 'ready' : 'not_started'
                     end

    {
      id: project.id,
      title: project.title,
      created_at: project.created_at.iso8601,
      last_modified_at: project.last_modified_at.iso8601,
      is_speech_interview: project.is_speech_interview,
      outline: {
        status: outline_status,
        chapters: chapters.map do |chapter|
          # Force associations to array to avoid queries
          sorted_sections = chapter.sections.to_a.sort_by(&:order)
          
          {
            chapter_id: chapter.id,
            title: chapter.title,
            order: chapter.order,
            omitted: chapter.omitted,
            sections: sorted_sections.map do |section|
              # Use loaded questions and filter in memory
              all_questions_in_section = section.questions.to_a
              base_questions = all_questions_in_section.select { |q| !q.is_follow_up }.sort_by(&:order)

              # Build the correctly ordered flat list, inserting follow-ups after their parents
              flat_ordered_questions = []
              base_questions.each do |base_q|
                flat_ordered_questions << base_q
                # Find and add follow-ups for this base question
                follow_ups = all_questions_in_section.select { |q| q.parent_question_id == base_q.id }.sort_by(&:order)
                flat_ordered_questions.concat(follow_ups)
              end

              {
                section_id: section.id,
                title: section.title,
                order: section.order,
                omitted: section.omitted,
                questions: flat_ordered_questions.map do |question|
                  {
                    question_id: question.id,
                    text: question.text,
                    order: question.order,
                    omitted: question.omitted,
                    parent_question_id: question.parent_question_id,
                    is_follow_up: question.is_follow_up
                  }
                end
              }
            end
          }
        end
      }
    }
  end

  def project_params
    # Handle both nested (:project key) and flat parameter formats for Swift client compatibility
    # When both are present, merge them with flat parameters taking precedence
    if params[:project].present? && params[:project].is_a?(ActionController::Parameters)
      # Nested format: { "project": { "initial_topic": "...", ... } }
      nested_params = params[:project].permit(:initial_topic, :is_speech_interview, :voice_id, :speech_rate, :interview_length, :question_count)
      flat_params = params.except(:controller, :action, :project).permit(:initial_topic, :is_speech_interview, :voice_id, :speech_rate, :interview_length, :question_count)
      
      # Merge both, with flat parameters taking precedence
      source_params = nested_params.to_h.merge(flat_params.to_h)
      source_params = ActionController::Parameters.new(source_params)
    else
      # Flat format only: { "initial_topic": "...", ... } (from Swift client)
      source_params = params.except(:controller, :action, :project)
    end
    
    permitted = source_params.permit(
      :initial_topic, 
      :is_speech_interview, 
      :voice_id, 
      :speech_rate,
      :interview_length,
      :question_count
    )
    
    permitted.tap do |p|
      # Rename initial_topic to topic for our model
      p[:topic] = p.delete(:initial_topic) if p[:initial_topic]
      # Preset parameters removed - using custom topics only
    end
  end

  # scaffold_project_from_preset method removed - presets disabled

  def generate_outline_for_project(project)
    Rails.logger.debug "=== GENERATE_OUTLINE DEBUG ==="
    Rails.logger.debug "Project ID: #{project.id}"
    Rails.logger.debug "Project topic: #{project.topic}"
    Rails.logger.debug "Project status before: #{project.status}"
    
    begin
      # Always use LLM service to generate interview outline (presets disabled)
      service = InterviewQuestionService.new
      Rails.logger.debug "InterviewQuestionService instantiated"
      
      outline = service.generate_interview_outline(project.topic)
      
      Rails.logger.debug "Outline ready: #{outline.inspect}"
      
      if outline[:error]
        Rails.logger.error "Outline generation failed: #{outline[:error]}"
        project.update!(status: 'failed')
        return
      end
      
      # Create chapters, sections, and questions from LLM-generated outline
      Rails.logger.debug "Creating chapters from outline..."
      Rails.logger.debug "Chapters count: #{outline[:chapters]&.length || 0}"
      
      new_question_ids = []
      
      ActiveRecord::Base.transaction do
        outline[:chapters]&.each do |chapter_data|
          Rails.logger.debug "Creating chapter: #{chapter_data[:title]}"
          chapter = project.chapters.create!(
            title: chapter_data[:title],
            order: chapter_data[:order],
            omitted: false
          )
          Rails.logger.debug "Chapter created with ID: #{chapter.id}"
          
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
      
      Rails.logger.debug "Updating project status to outline_ready"
      project.update!(status: 'outline_ready')
      Rails.logger.debug "Final project status: #{project.reload.status}"
      
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
    rescue => e
      Rails.logger.error "Outline generation failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      project.update!(status: 'failed')
    end
  end


end
