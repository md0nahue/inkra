class InterviewFlowService
  def initialize(project)
    @project = project
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Initialized with project id: #{@project.id}, title: #{@project.title}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Project is_speech_interview: #{@project.is_speech_interview}, status: #{@project.status}"
  end

  def generate_question_queue
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Starting generate_question_queue for project #{@project.id}"
    
    answered_question_ids = get_answered_question_ids
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Answered question IDs: #{answered_question_ids.inspect}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Array of integers, ACTUAL: #{answered_question_ids.class.name} with #{answered_question_ids.size} items"
    
    # Get all non-omitted, non-skipped questions for the project
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Fetching all non-omitted questions"
    all_questions = @project.questions
                             .joins(section: :chapter)
                             .includes(section: { chapter: :project }, polly_audio_clip: [])
                             .where(omitted: false, skipped: false, sections: { omitted: false }, chapters: { omitted: false })
                             .order("chapters.order ASC, sections.order ASC, questions.order ASC")
    
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] All questions count: #{all_questions.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: ActiveRecord::Relation with questions, ACTUAL: #{all_questions.class.name}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] First 3 questions: #{all_questions.first(3).map { |q| { id: q.id, text: q.text[0..50], is_follow_up: q.is_follow_up } }}"

    # Filter out the questions that have already been answered
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Filtering out answered questions"
    unanswered_questions = all_questions.reject { |q| answered_question_ids.include?(q.id) }
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Unanswered questions count: #{unanswered_questions.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Fewer questions than all_questions, ACTUAL: #{all_questions.size} - #{answered_question_ids.size} = #{unanswered_questions.size}"
    
    # Sort to place follow-ups immediately after their answered parents.
    # And prioritize any unanswered follow-ups whose parents ARE answered.
    
    # Separate into three groups:
    # 1. Urgent follow-ups (parent answered, follow-up is not)
    # 2. Standard main questions
    # 3. Follow-ups whose parents haven't been answered yet
    
    urgent_follow_ups = unanswered_questions.select do |q|
      is_urgent = q.is_follow_up? && q.parent_question_id.in?(answered_question_ids)
      if is_urgent
        Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Found urgent follow-up: question_id=#{q.id}, parent_id=#{q.parent_question_id}"
      end
      is_urgent
    end
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Urgent follow-ups found: #{urgent_follow_ups.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Follow-ups with answered parents, ACTUAL: #{urgent_follow_ups.map { |q| { id: q.id, parent: q.parent_question_id } }}"
    
    standard_queue = unanswered_questions.reject do |q|
      q.is_follow_up?
    end
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Standard questions (non-follow-ups): #{standard_queue.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Main questions only, ACTUAL: #{standard_queue.first(3).map { |q| { id: q.id, is_follow_up: q.is_follow_up } }}"

    # The final queue is urgent follow-ups first, then the rest of the standard questions.
    # This ensures that as soon as a question is answered, its follow-ups jump to the front of the line.
    final_queue = (urgent_follow_ups + standard_queue).uniq(&:id)

    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Final queue composition:"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Total questions: #{final_queue.length}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Urgent follow-ups: #{urgent_follow_ups.count}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Standard questions: #{standard_queue.count}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: urgent_follow_ups + standard_queue, ACTUAL: #{final_queue.length} total"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] First 5 in queue: #{final_queue.first(5).map { |q| { id: q.id, is_follow_up: q.is_follow_up, parent: q.parent_question_id } }}"
    
    return final_queue
  end

  # Insert new follow-up questions into an existing queue at the optimal position
  def insert_followup_questions(current_queue, parent_question_id, new_followups)
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] insert_followup_questions called"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Current queue size: #{current_queue.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Parent question ID: #{parent_question_id}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - New follow-ups count: #{new_followups.size}"
    
    return current_queue if new_followups.empty?
    
    # Find the parent question index in the current queue
    parent_index = current_queue.find_index { |q| q.id == parent_question_id }
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Parent question index: #{parent_index}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Integer index >= 0, ACTUAL: #{parent_index.inspect}"
    
    unless parent_index
      Rails.logger.warn "[INTERVIEW_FLOW_DEBUG] Parent question #{parent_question_id} not found in queue!"
      return current_queue
    end
    
    # Find the insertion point (after parent and existing follow-ups)
    insertion_index = find_insertion_point(current_queue, parent_index, parent_question_id)
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Insertion index: #{insertion_index}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Index after parent and existing follow-ups, ACTUAL: #{insertion_index}"
    
    # Insert new follow-ups at the calculated position
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Inserting #{new_followups.size} follow-ups at position #{insertion_index}"
    current_queue.insert(insertion_index, *new_followups)
    
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Queue size after insertion: #{current_queue.size}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Original size + new follow-ups, ACTUAL: #{current_queue.size}"
    
    current_queue
  end

  # Get the next priority question that should be asked
  def get_next_priority_question(current_queue, current_index)
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] get_next_priority_question called"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Queue size: #{current_queue.length}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG]   - Current index: #{current_index}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Valid index < queue.length - 1, ACTUAL: #{current_index} < #{current_queue.length - 1}"
    
    # Check if there are any new high-priority follow-ups that should be inserted
    # before continuing with the regular flow
    
    # For now, just return the next question in sequence
    if current_index >= current_queue.length - 1
      Rails.logger.info "[INTERVIEW_FLOW_DEBUG] No more questions available (at end of queue)"
      return nil
    end
    
    next_question = current_queue[current_index + 1]
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Next question: id=#{next_question.id}, is_follow_up=#{next_question.is_follow_up}"
    next_question
  end

  private

  def get_base_questions_ordered
    @project.questions
            .joins(:section)
            .where(is_follow_up: false)
            .where(sections: { omitted: false }, omitted: false)
            .includes(:section, follow_up_questions: [])
            .order('sections.order ASC, questions.order ASC')
  end

  def get_all_existing_followups
    @project.questions
            .joins(:section)
            .where(is_follow_up: true)
            .where(sections: { omitted: false }, omitted: false)
            .includes(:section)
            .order('questions.parent_question_id ASC, questions.order ASC')
  end

  def get_followup_questions_for(parent_question)
    # Follow-up questions are now preloaded, so filter in memory
    parent_question.follow_up_questions
                   .select { |q| !q.omitted }
                   .sort_by(&:order)
  end

  def find_insertion_point(queue, parent_index, parent_question_id)
    # Start looking after the parent question
    index = parent_index + 1
    
    # Skip over existing follow-ups for the same parent
    while index < queue.length && 
          queue[index].is_follow_up && 
          queue[index].parent_question_id == parent_question_id
      index += 1
    end
    
    index
  end

  def get_answered_question_ids
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Getting answered question IDs for project #{@project.id}"
    
    # Get all question IDs that have associated audio segments
    segments = @project.audio_segments.where.not(question_id: nil)
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Found #{segments.count} audio segments with question_ids"
    
    question_ids = segments.distinct.pluck(:question_id)
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] Distinct question IDs: #{question_ids.inspect}"
    Rails.logger.info "[INTERVIEW_FLOW_DEBUG] EXPECTED: Array of non-nil integers, ACTUAL: #{question_ids.select(&:nil?).any? ? 'Contains nil!' : 'All valid'}"
    
    question_ids
  end
end