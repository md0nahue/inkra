class Api::ExportsController < Api::BaseController
  include ErrorResponder
  
  before_action :set_project

  # Export project transcript as PDF
  def pdf
    export_data = generate_export_data
    pdf_content = generate_pdf(export_data)
    
    send_data pdf_content,
      filename: generate_project_filename('pdf', export_data),
      type: 'application/pdf',
      disposition: 'attachment'
  end

  # Export project transcript as DOCX
  def docx
    export_data = generate_export_data
    docx_content = generate_docx(export_data)
    
    send_data docx_content,
      filename: generate_project_filename('docx', export_data),
      type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      disposition: 'attachment'
  end

  # Export project transcript as TXT
  def txt
    export_data = generate_export_data
    txt_content = generate_txt(export_data)
    
    send_data txt_content,
      filename: generate_project_filename('txt', export_data),
      type: 'text/plain',
      disposition: 'attachment'
  end

  # Export project transcript as CSV
  def csv
    export_data = generate_export_data
    csv_content = generate_csv(export_data)
    
    send_data csv_content,
      filename: generate_project_filename('csv', export_data),
      type: 'text/csv',
      disposition: 'attachment'
  end

  # Get export preview data (JSON)
  def preview
    export_data = generate_export_data
    
    render json: {
      project: {
        title: @project.title,
        topic: @project.topic,
        created_at: @project.created_at.iso8601,
        status: @project.status
      },
      outline: export_data[:outline],
      transcript: export_data[:transcript],
      raw_text: export_data[:raw_text],
      polished_text: export_data[:polished_text],
      statistics: {
        total_questions: export_data[:statistics][:total_questions],
        answered_questions: export_data[:statistics][:answered_questions],
        total_recording_time: export_data[:statistics][:total_recording_time],
        total_words: export_data[:statistics][:total_words]
      }
    }
  end

  # Export podcast audio - start background job to stitch audio segments
  def podcast
    # Check if project has any audio segments
    audio_segments = @project.audio_segments.where.not(audio_file_key: nil)
    
    if audio_segments.empty?
      render json: { 
        error: "No audio segments available for podcast export",
        message: "This project doesn't have any recorded audio to export."
      }, status: :unprocessable_entity
      return
    end

    # Start background job to create the podcast
    job_id = PodcastExportJob.perform_async(@project.id, current_user.id)
    
    render json: {
      job_id: job_id,
      message: "Podcast export started. This may take a few minutes to process.",
      total_segments: audio_segments.count,
      estimated_duration: format_duration(audio_segments.sum(:duration_seconds))
    }
  rescue => e
    Rails.logger.error "Podcast export failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: { 
      error: "Failed to start podcast export",
      message: e.message 
    }, status: :internal_server_error
  end

  # Check podcast export status
  def podcast_status
    job_id = params[:job_id]
    
    unless job_id
      render json: { error: "Job ID is required" }, status: :bad_request
      return
    end

    # Check Sidekiq job status
    if Sidekiq::Status.exists?(job_id)
      status = Sidekiq::Status.status(job_id)
      progress = Sidekiq::Status.pct_complete(job_id)
      
      case status
      when 'complete'
        # Get the result from Redis or database
        result = Sidekiq::Status.get_all(job_id)
        
        render json: {
          status: 'completed',
          progress: 100,
          download_url: result['download_url'],
          filename: result['filename'],
          file_size: result['file_size'],
          duration: result['duration']
        }
      when 'failed'
        error_message = Sidekiq::Status.get_all(job_id)['error']
        render json: {
          status: 'failed',
          progress: progress,
          error: error_message || 'Unknown error occurred'
        }
      else
        current_step = Sidekiq::Status.get_all(job_id)['current_step']
        render json: {
          status: status,
          progress: progress,
          current_step: current_step || 'Processing audio segments'
        }
      end
    else
      render json: {
        status: 'not_found',
        error: 'Job not found or has expired'
      }, status: :not_found
    end
  rescue => e
    Rails.logger.error "Podcast status check failed: #{e.message}"
    
    render json: { 
      error: "Failed to check podcast status",
      message: e.message 
    }, status: :internal_server_error
  end

  # Generate shareable link for export
  def share_link
    export_data = generate_export_data
    format = params[:format] || 'txt'
    
    # Generate content based on format
    content = case format
              when 'csv'
                generate_csv(export_data)
              when 'pdf'
                generate_pdf(export_data)
              when 'docx'
                generate_docx(export_data)
              else
                generate_txt(export_data)
              end
    
    # Generate filename
    filename = generate_project_filename(format, export_data)
    
    # Store in S3 and get shareable URL
    s3_service = S3Service.new(current_user)
    s3_result = s3_service.store_export_file(
      content: content,
      filename: filename,
      project_id: @project.id,
      format: format,
      expires_in: 7.days
    )
    
    render json: {
      share_url: s3_result[:share_url],
      filename: filename,
      expires_at: (Time.current + 7.days).iso8601,
      format: format
    }
  rescue => e
    Rails.logger.error "Share link generation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    render json: { 
      error: "Failed to generate share link",
      message: e.message 
    }, status: :internal_server_error
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      "Project not found",
      "PROJECT_NOT_FOUND",
      :not_found
    )
  end

  def generate_export_data
    # Get transcript version from params (default to 'edited')
    transcript_version = params[:transcript_version] || 'edited'
    include_outline = params[:include_outline] != 'false'
    include_transcript = params[:include_transcript] != 'false'
    include_questions = params[:include_questions] != 'false'
    
    begin
      # Get basic project data
      outline = []
      if include_outline
        chapters = @project.chapters.includes(sections: :questions)
        
        outline = chapters.map do |chapter|
          {
            title: chapter.title,
            order: chapter.order,
            omitted: chapter.omitted,
            sections: chapter.sections.map do |section|
              {
                title: section.title,
                order: section.order,
                omitted: section.omitted,
                questions: section.questions.map do |question|
                  {
                    question_id: question.id,
                    text: question.text,
                    order: question.order,
                    omitted: question.omitted,
                    audio_segments: question.audio_segments.map do |segment|
                      {
                        id: segment.id,
                        transcription_text: segment.transcription_text,
                        duration_seconds: segment.duration_seconds
                      }
                    end
                  }
                end
              }
            end
          }
        end
      end

      # Get transcript data based on version
      transcript = []
      raw_text = nil
      polished_text = nil
      
      if include_transcript && @project.transcript
        # Get the complete text versions
        raw_text = @project.transcript.raw_content
        polished_text = @project.transcript.polished_content
        
        # For backward compatibility, also provide structured content
        if transcript_version == 'raw'
          transcript = @project.transcript.raw_structured_content_json || []
        else
          transcript = @project.transcript.edited_content_json || []
        end
      end
      
      # Calculate basic statistics
      total_questions = @project.questions.count
      total_audio_segments = @project.audio_segments.count
      total_recording_time = @project.audio_segments.sum(:duration_seconds) || 0
      
      # Calculate word count based on available transcript content
      total_words = 0
      if polished_text.present?
        total_words = polished_text.split(/\s+/).length
      elsif raw_text.present?
        total_words = raw_text.split(/\s+/).length
      else
        total_words = estimate_word_count(transcript)
      end

      statistics = {
        total_questions: total_questions,
        answered_questions: total_audio_segments,
        total_recording_time: total_recording_time,
        total_words: total_words
      }

      {
        outline: outline,
        transcript: transcript,
        raw_text: raw_text,
        polished_text: polished_text,
        statistics: statistics,
        transcript_version: transcript_version,
        include_questions: include_questions
      }
    rescue => e
      Rails.logger.error "Export data generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Return minimal data structure
      {
        outline: [],
        transcript: [],
        raw_text: nil,
        polished_text: nil,
        statistics: {
          total_questions: 0,
          answered_questions: 0,
          total_recording_time: 0,
          total_words: 0
        },
        transcript_version: transcript_version,
        include_questions: include_questions
      }
    end
  end


  def generate_pdf(export_data)
    # Simple PDF generation using HTML to PDF approach
    # In production, you'd want to use a proper PDF library like Prawn
    html_content = generate_html_content(export_data)
    
    # For now, return a simple text-based PDF placeholder
    # In production, integrate with a PDF generation service
    "PDF Export Placeholder\n\n#{generate_txt(export_data)}"
  end

  def generate_docx(export_data)
    # DOCX generation placeholder
    # In production, use a library like ruby-docx or integrate with an external service
    "DOCX Export Placeholder\n\n#{generate_txt(export_data)}"
  end

  def generate_txt(export_data)
    content = []
    
    # Header
    content << "#{@project.title}"
    content << "=" * @project.title.length
    content << ""
    content << "Topic: #{@project.topic}"
    content << "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    content << "Status: #{@project.status.humanize}"
    content << "Transcript Version: #{export_data[:transcript_version].humanize}"
    content << ""
    
    # Statistics
    stats = export_data[:statistics]
    content << "STATISTICS"
    content << "-" * 10
    content << "Total Questions: #{stats[:total_questions]}"
    content << "Answered Questions: #{stats[:answered_questions]}"
    content << "Total Recording Time: #{format_duration(stats[:total_recording_time])}"
    content << "Total Words: #{stats[:total_words]}"
    content << ""
    
    # Transcript Content
    transcript_text = nil
    if export_data[:transcript_version] == 'raw' && export_data[:raw_text].present?
      transcript_text = export_data[:raw_text]
    elsif export_data[:polished_text].present?
      transcript_text = export_data[:polished_text]
    end
    
    if transcript_text.present?
      content << "INTERVIEW TRANSCRIPT (#{export_data[:transcript_version].upcase})"
      content << "=" * 30
      content << ""
      
      # If include_questions is true and we have outline data, interleave questions with answers
      if export_data[:include_questions] && export_data[:outline].any?
        export_data[:outline].each do |chapter|
          next if chapter[:omitted]
          
          content << ""
          content << "#{chapter[:title]}"
          content << "=" * chapter[:title].length
          content << ""
          
          chapter[:sections].each do |section|
            next if section[:omitted]
            
            content << "#{section[:title]}"
            content << "-" * section[:title].length
            content << ""
            
            section[:questions].each do |question|
              next if question[:omitted]
              
              # Include question text
              content << "Q: #{question[:text]}"
              content << ""
              
              # Include corresponding answer if available
              question[:audio_segments].each do |segment|
                if segment[:transcription_text].present?
                  content << segment[:transcription_text]
                  content << ""
                end
              end
            end
          end
        end
      else
        # Just the transcript without questions
        content << transcript_text
        content << ""
      end
    elsif export_data[:transcript].any?
      content << "INTERVIEW TRANSCRIPT (#{export_data[:transcript_version].upcase})"
      content << "=" * 30
      content << ""
      
      current_chapter = nil
      current_section = nil
      
      export_data[:transcript].each do |item|
        case item['type']
        when 'chapter'
          current_chapter = item
          content << "#{item['title']}"
          content << "=" * item['title'].length
          content << ""
        when 'section'
          current_section = item
          content << "#{item['title']}"
          content << "-" * item['title'].length
          content << ""
        when 'paragraph'
          if item['text'].present?
            # If include_questions is true and paragraph has question_id, find and display the question
            if export_data[:include_questions] && item['question_id'].present? && export_data[:outline].any?
              question_text = find_question_text(export_data[:outline], item['question_id'])
              if question_text
                content << "Q: #{question_text}"
                content << ""
              end
            end
            
            content << item['text']
            content << ""
          end
        end
      end
    else
      content << "No transcript content available."
      content << ""
    end
    
    content.join("\n")
  end

  def generate_html_content(export_data)
    # HTML template for PDF conversion
    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>#{@project.title} - Interview Transcript</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          h1 { color: #333; border-bottom: 2px solid #333; }
          h2 { color: #666; margin-top: 30px; }
          h3 { color: #888; }
          .question { margin: 20px 0; }
          .answer { margin-left: 20px; background: #f5f5f5; padding: 10px; border-radius: 5px; }
          .metadata { color: #888; font-size: 0.9em; }
          .stats { background: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
        </style>
      </head>
      <body>
        <h1>#{@project.title}</h1>
        <div class="metadata">
          <p><strong>Topic:</strong> #{@project.topic}</p>
          <p><strong>Generated:</strong> #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}</p>
          <p><strong>Status:</strong> #{@project.status.humanize}</p>
        </div>
        
        <div class="stats">
          <h2>Statistics</h2>
          <p><strong>Total Questions:</strong> #{export_data[:statistics][:total_questions]}</p>
          <p><strong>Answered Questions:</strong> #{export_data[:statistics][:answered_questions]}</p>
          <p><strong>Total Recording Time:</strong> #{format_duration(export_data[:statistics][:total_recording_time])}</p>
          <p><strong>Total Words:</strong> #{export_data[:statistics][:total_words]}</p>
        </div>
        
        <h2>Interview Transcript</h2>
        #{generate_html_outline(export_data[:outline])}
      </body>
      </html>
    HTML
    
    html
  end

  def generate_html_outline(outline)
    content = ""
    
    outline.each do |chapter|
      next if chapter[:omitted]
      
      content += "<h2>#{chapter[:order]}. #{chapter[:title]}</h2>"
      
      chapter[:sections].each do |section|
        next if section[:omitted]
        
        content += "<h3>#{section[:order]}. #{section[:title]}</h3>"
        
        section[:questions].each do |question|
          next if question[:omitted]
          
          content += "<div class='question'>"
          content += "<p><strong>Q:</strong> #{question[:text]}</p>"
          
          (question[:audio_segments] || []).each do |segment|
            if segment[:transcription_text].present?
              content += "<div class='answer'>"
              content += "<p>#{segment[:transcription_text]}</p>"
              content += "<p class='metadata'>Duration: #{format_duration(segment[:duration_seconds])}</p>"
              content += "</div>"
            end
          end
          
          if question[:follow_up_questions]&.any?
            content += "<div style='margin-left: 20px;'>"
            content += "<p><strong>Follow-up Questions:</strong></p>"
            question[:follow_up_questions].each do |followup|
              next if followup[:omitted]
              content += "<p>• #{followup[:text]}</p>"
              
              (followup[:audio_segments] || []).each do |segment|
                if segment[:transcription_text].present?
                  content += "<div class='answer' style='margin-left: 20px;'>"
                  content += "<p>#{segment[:transcription_text]}</p>"
                  content += "</div>"
                end
              end
            end
            content += "</div>"
          end
          
          content += "</div>"
        end
      end
    end
    
    content
  end

  def format_duration(seconds)
    return "0 seconds" if seconds.nil? || seconds == 0
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remaining_seconds = seconds % 60
    
    parts = []
    parts << "#{hours} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{minutes} minute#{'s' if minutes != 1}" if minutes > 0
    parts << "#{remaining_seconds} second#{'s' if remaining_seconds != 1}" if remaining_seconds > 0 || parts.empty?
    
    parts.join(", ")
  end

  def estimate_word_count(transcript_content)
    return 0 unless transcript_content.is_a?(Array)
    
    word_count = 0
    transcript_content.each do |item|
      if item['type'] == 'paragraph' && item['text'].present?
        word_count += item['text'].split(/\s+/).length
      end
    end
    
    word_count
  end

  def generate_csv(export_data)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      if export_data[:include_questions]
        csv << ['Chapter', 'Section', 'Question', 'Answer', 'Type']
      else
        csv << ['Chapter', 'Section', 'Content', 'Type']
      end
      
      # Use the structured outline data if available
      if export_data[:outline].any?
        export_data[:outline].each do |chapter|
          next if chapter[:omitted]
          
          chapter[:sections].each do |section|
            next if section[:omitted]
            
            section[:questions].each do |question|
              next if question[:omitted]
              
              # Combine all audio segments for this question
              answer_text = question[:audio_segments]
                .select { |seg| seg[:transcription_text].present? }
                .map { |seg| seg[:transcription_text] }
                .join(' ')
              
              if export_data[:include_questions]
                csv << [
                  chapter[:title],
                  section[:title],
                  question[:text],
                  answer_text,
                  export_data[:transcript_version]
                ]
              else
                csv << [
                  chapter[:title],
                  section[:title],
                  answer_text,
                  export_data[:transcript_version]
                ]
              end
            end
          end
        end
      elsif export_data[:transcript].any?
        # Use transcript structure
        current_chapter = nil
        current_section = nil
        
        export_data[:transcript].each do |item|
          case item['type']
          when 'chapter'
            current_chapter = item['title']
          when 'section'
            current_section = item['title']
          when 'paragraph'
            if item['text'].present?
              if export_data[:include_questions] && item['question_id'].present?
                question_text = find_question_text(export_data[:outline], item['question_id'])
                csv << [
                  current_chapter || '',
                  current_section || '',
                  question_text || '',
                  item['text'],
                  export_data[:transcript_version]
                ]
              else
                csv << [
                  current_chapter || '',
                  current_section || '',
                  item['text'],
                  export_data[:transcript_version]
                ]
              end
            end
          end
        end
      else
        # Fallback to raw text if available
        content = export_data[:transcript_version] == 'raw' ? export_data[:raw_text] : export_data[:polished_text]
        if content.present?
          csv << ['', '', content, export_data[:transcript_version]]
        end
      end
    end
  end

  def find_question_text(outline, question_id)
    outline.each do |chapter|
      chapter[:sections].each do |section|
        section[:questions].each do |question|
          return question[:text] if question[:question_id] == question_id
        end
      end
    end
    nil
  end

  def generate_project_filename(format, export_data)
    # Start with first 15 characters of project title
    title_part = @project.title.parameterize.underscore
    title_part = title_part[0..14] if title_part.length > 15  # Limit to first 15 characters
    
    # Add date for uniqueness
    date_part = Time.current.strftime('%Y%m%d')
    
    "#{title_part}_#{date_part}.#{format}"
  end
end