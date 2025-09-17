class TranscriptContentAssemblerService
  def self.process_transcript(project_id)
    project = Project.find_by(id: project_id)
    unless project
      Rails.logger.warn "TranscriptContentAssemblerService: Project with id #{project_id} not found"
      return { success: false, error: "Project not found" }
    end
    
    begin
      Rails.logger.info "Starting transcript processing for project #{project_id}"
      
      # Simulate LLM processing delay
      simulate_processing_delay
      
      # Get all transcribed audio segments for this project
      transcribed_segments = project.audio_segments
                                   .where(upload_status: 'transcribed')
                                   .includes(:question => { :section => :chapter })
                                   .order('questions.order ASC')
      
      if transcribed_segments.empty?
        Rails.logger.warn "No transcribed segments found for project #{project_id}"
        return { success: false, error: 'No transcribed content available' }
      end
      
      # Generate structured content (for backward compatibility)
      structured_content = generate_structured_content(project, transcribed_segments)
      
      # Create or update transcript record with structured content only
      transcript = project.transcript || project.build_transcript
      transcript.update!(
        status: 'processing_raw',
        raw_structured_content_json: structured_content,
        last_updated: Time.current
      )
      
      Rails.logger.info "Transcript processing completed for project #{project_id}"
      
      { success: true, transcript_id: transcript.id }
      
    rescue => e
      Rails.logger.error "Transcript processing error for project #{project_id}: #{e.message}"
      project.update!(status: 'failed')
      { success: false, error: e.message }
    end
  end

  def self.finalize_transcript(project_id)
    project = Project.find_by(id: project_id)
    unless project
      Rails.logger.warn "TranscriptContentAssemblerService: Project with id #{project_id} not found for finalization"
      return { success: false, error: "Project not found" }
    end
    
    begin
      Rails.logger.info "Finalizing transcript for project #{project_id}"
      
      # Get all transcribed audio segments for this project
      transcribed_segments = project.audio_segments
                                   .where(upload_status: 'transcribed')
                                   .includes(:question => { :section => :chapter })
                                   .order('questions.order ASC')
      
      if transcribed_segments.empty?
        Rails.logger.warn "No transcribed segments found for project #{project_id}"
        return { success: false, error: 'No transcribed content available' }
      end
      
      # Generate both structured content and raw plaintext content
      structured_content = generate_structured_content(project, transcribed_segments)
      raw_transcript = generate_raw_transcript(project, transcribed_segments)
      
      # Create or update transcript record with both formats
      transcript = project.transcript || project.build_transcript
      transcript.update!(
        status: 'raw_ready',
        raw_structured_content_json: structured_content,
        raw_content: raw_transcript,
        last_updated: Time.current
      )
      
      # Enqueue editing job to polish the complete transcript
      TranscriptEditingJob.perform_later(project.id)
      
      Rails.logger.info "Transcript finalization completed for project #{project_id}"
      
      { success: true, transcript_id: transcript.id }
      
    rescue => e
      Rails.logger.error "Transcript finalization error for project #{project_id}: #{e.message}"
      project.update!(status: 'failed')
      { success: false, error: e.message }
    end
  end

  def self.generate_complete_transcript(project_id, enqueue_editing_job: true)
    project = Project.find(project_id)
    
    begin
      Rails.logger.info "Generating complete transcript for project #{project_id}"
      
      # Get all transcribed audio segments for this project
      transcribed_segments = project.audio_segments
                                   .where(upload_status: 'transcribed')
                                   .includes(:question => { :section => :chapter })
                                   .order('questions.order ASC')
      
      if transcribed_segments.empty?
        Rails.logger.warn "No transcribed segments found for project #{project_id}"
        return { success: false, error: 'No transcribed content available' }
      end
      
      # Generate raw plaintext transcript
      raw_transcript = generate_raw_transcript(project, transcribed_segments)
      
      # Update transcript record with complete raw content
      transcript = project.transcript || project.build_transcript
      transcript.update!(
        status: 'raw_ready',
        raw_content: raw_transcript,
        last_updated: Time.current
      )
      
      # Enqueue editing job to polish the complete transcript
      if enqueue_editing_job
        TranscriptEditingJob.perform_later(project.id)
      end
      
      Rails.logger.info "Complete transcript generation completed for project #{project_id}"
      
      { success: true, transcript_id: transcript.id }
      
    rescue => e
      Rails.logger.error "Complete transcript generation error for project #{project_id}: #{e.message}"
      project.update!(status: 'failed')
      { success: false, error: e.message }
    end
  end

  private

  def self.simulate_processing_delay
    # Simulate realistic LLM processing time (3-10 seconds)
    delay = rand(3..10)
    Rails.logger.info "Simulating transcript processing delay: #{delay} seconds"
    sleep(delay) if Rails.env.development?
  end

  def self.generate_structured_content(project, transcribed_segments)
    content = []
    
    # Group segments by chapter and section
    chapters_data = group_segments_by_structure(transcribed_segments)
    
    chapters_data.each do |chapter_info|
      # Add chapter header
      content << {
        type: 'chapter',
        chapterId: chapter_info[:chapter].id,
        title: chapter_info[:chapter].title,
        text: nil,
        audioSegmentId: nil
      }
      
      chapter_info[:sections].each do |section_info|
        # Add section header if section exists
        if section_info[:section]
          content << {
            type: 'section',
            sectionId: section_info[:section].id,
            title: section_info[:section].title,
            text: nil,
            audioSegmentId: nil
          }
        end
        
        # Process each question's transcription into structured paragraphs
        section_info[:segments].each do |segment|
          structured_paragraphs = structure_transcription_text(
            segment.transcription_text, 
            segment.question&.text
          )
          
          structured_paragraphs.each do |paragraph_text|
            content << {
              type: 'paragraph',
              chapterId: chapter_info[:chapter].id,
              sectionId: section_info[:section]&.id,
              questionId: segment.question&.id,
              text: paragraph_text,
              audioSegmentId: segment.id
            }
          end
        end
      end
    end
    
    content
  end

  def self.group_segments_by_structure(segments)
    chapters = {}
    
    segments.each do |segment|
      question = segment.question
      next unless question
      
      section = question.section
      chapter = section.chapter
      
      chapters[chapter.id] ||= {
        chapter: chapter,
        sections: {}
      }
      
      section_id = section&.id || 'no_section'
      chapters[chapter.id][:sections][section_id] ||= {
        section: section,
        segments: []
      }
      
      chapters[chapter.id][:sections][section_id][:segments] << segment
    end
    
    # Convert to sorted array
    chapters.values.sort_by { |c| c[:chapter].order }.map do |chapter_data|
      {
        chapter: chapter_data[:chapter],
        sections: chapter_data[:sections].values.sort_by { |s| s[:section]&.order || 0 }
      }
    end
  end

  def self.structure_transcription_text(transcription_text, question_text = nil)
    return [transcription_text] if transcription_text.blank?
    
    # Just return raw text for raw structured content
    [transcription_text]
  end

  def self.generate_raw_transcript(project, transcribed_segments)
    transcript_parts = []
    
    # Group segments by chapter and section
    chapters_data = group_segments_by_structure(transcribed_segments)
    
    chapters_data.each do |chapter_info|
      # Add chapter header
      transcript_parts << "# #{chapter_info[:chapter].title}\n\n"
      
      chapter_info[:sections].each do |section_info|
        # Add section header if section exists
        if section_info[:section]
          transcript_parts << "## #{section_info[:section].title}\n\n"
        end
        
        # Add each question and its response
        section_info[:segments].each do |segment|
          if segment.question&.text.present?
            transcript_parts << "**Question:** #{segment.question.text}\n\n"
          end
          
          if segment.transcription_text.present?
            transcript_parts << "#{segment.transcription_text}\n\n"
          end
        end
      end
    end
    
    transcript_parts.join.strip
  end

end