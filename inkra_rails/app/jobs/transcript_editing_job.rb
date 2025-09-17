class TranscriptEditingJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find(project_id)
    transcript = project.transcript
    
    unless transcript && (transcript.raw_content.present? || transcript.raw_structured_content.present?)
      Rails.logger.error "No raw content available for project #{project_id}"
      return
    end

    Rails.logger.info "Starting transcript editing for project #{project_id}"

    begin
      # Set status to editing
      transcript.update!(status: 'editing')

      # Use raw plaintext if available, otherwise fall back to structured content
      raw_content = transcript.raw_content.present? ? transcript.raw_content : transcript.raw_structured_content_json

      # Call Gemini to polish the transcript
      polished_content = GeminiTextPolishingService.polish_transcript(raw_content)

      if polished_content.present?
        # Update transcript with polished content
        transcript.update!(
          polished_content: polished_content,
          status: 'ready',
          last_updated: Time.current
        )
        
        # For backward compatibility, also update edited_content if using structured content
        if transcript.raw_content.blank? && transcript.raw_structured_content.present?
          structured_polished = GeminiTextPolishingService.polish_transcript_structured(transcript.raw_structured_content_json)
          polished_content_with_ids = map_ids_to_polished_content(structured_polished, transcript.raw_structured_content_json)
          transcript.update!(edited_content_json: polished_content_with_ids)
        end
        
        # Mark project as completed
        project.update!(status: 'completed', last_modified_at: Time.current)
        
        Rails.logger.info "Transcript editing completed for project #{project_id}"
      else
        raise "Gemini polishing returned empty content"
      end

    rescue => e
      Rails.logger.error "Transcript editing failed for project #{project_id}: #{e.message}"
      transcript.update!(status: 'failed') if transcript.persisted?
      project.update!(status: 'failed') if project.persisted?
      raise e
    end
  end

  private

  def map_ids_to_polished_content(polished_content, raw_content)
    # Create lookup maps from raw content
    chapter_map = {}
    section_map = {}
    question_map = {}
    audio_segment_map = {}

    raw_content.each do |item|
      case item['type']
      when 'chapter'
        chapter_map[item['title']] = {
          id: item['chapterId'],
          title: item['title']
        }
      when 'section'
        section_map[item['title']] = {
          id: item['sectionId'],
          title: item['title']
        }
      when 'paragraph'
        if item['questionId']
          question_map[item['text']] = item['questionId']
        end
        if item['audioSegmentId']
          audio_segment_map[item['text']] = item['audioSegmentId']
        end
      end
    end

    # Map IDs to polished content
    current_chapter_id = nil
    current_section_id = nil

    polished_content.map do |item|
      case item['type']
      when 'chapter'
        current_chapter_id = chapter_map[item['title']]&.dig(:id)
        item.merge(
          'chapterId' => current_chapter_id
        )
      when 'section'
        current_section_id = section_map[item['title']]&.dig(:id)
        item.merge(
          'sectionId' => current_section_id
        )
      when 'paragraph'
        # Try to find matching question and audio segment from raw content
        best_question_id = find_best_matching_question_id(item['text'], raw_content)
        best_audio_segment_id = find_best_matching_audio_segment_id(item['text'], raw_content)
        
        item.merge(
          'chapterId' => current_chapter_id,
          'sectionId' => current_section_id,
          'questionId' => best_question_id,
          'audioSegmentId' => best_audio_segment_id
        )
      else
        item
      end
    end
  end

  def find_best_matching_question_id(polished_text, raw_content)
    # Find the raw paragraph with the highest similarity to the polished text
    best_match = nil
    best_score = 0

    raw_content.each do |item|
      next unless item['type'] == 'paragraph' && item['questionId']
      
      similarity = calculate_text_similarity(polished_text, item['text'])
      if similarity > best_score
        best_score = similarity
        best_match = item['questionId']
      end
    end

    best_match
  end

  def find_best_matching_audio_segment_id(polished_text, raw_content)
    # Find the raw paragraph with the highest similarity to the polished text
    best_match = nil
    best_score = 0

    raw_content.each do |item|
      next unless item['type'] == 'paragraph' && item['audioSegmentId']
      
      similarity = calculate_text_similarity(polished_text, item['text'])
      if similarity > best_score
        best_score = similarity
        best_match = item['audioSegmentId']
      end
    end

    best_match
  end

  def calculate_text_similarity(text1, text2)
    return 0 if text1.blank? || text2.blank?
    
    # Simple word-based similarity calculation
    words1 = text1.downcase.split(/\W+/).reject(&:empty?)
    words2 = text2.downcase.split(/\W+/).reject(&:empty?)
    
    return 0 if words1.empty? || words2.empty?
    
    common_words = (words1 & words2).length
    total_words = (words1 | words2).length
    
    common_words.to_f / total_words
  end
end