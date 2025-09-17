require 'csv'
require 'zip'
require 'fileutils'

class UserDataExportService
  def initialize(user, export_record = nil)
    @user = user
    @export_record = export_record
    @export_timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
  end

  def create_complete_export
    Rails.logger.info "Creating complete data export for user #{@user.id}"
    
    # Update status to processing
    @export_record&.update!(status: 'processing')
    
    # Create temporary directory for export
    export_dir = create_export_directory
    
    begin
      # Capture current data IDs for freshness tracking
      current_project_id = @user.projects.maximum(:id) || 0
      current_audio_segment_id = @user.projects.joins(:audio_segments).maximum('audio_segments.id') || 0
      
      # Generate CSV files
      csv_files = generate_csv_files(export_dir)
      
      # Download and organize S3 files
      s3_files = collect_s3_files(export_dir)
      
      # Create README file
      create_readme_file(export_dir, csv_files.keys, s3_files.keys)
      
      # Create zip file
      zip_path = create_zip_file(export_dir)
      
      # Upload to S3 and get file info
      s3_key, file_size = upload_to_s3(zip_path)
      file_count = csv_files.size + s3_files.values.sum { |desc| desc.to_s.scan(/\d+/).first.to_i }
      
      # Update export record with completion info
      if @export_record
        @export_record.update!(
          status: 'completed',
          s3_key: s3_key,
          file_count: file_count,
          total_size_bytes: file_size,
          highest_project_id: current_project_id,
          highest_audio_segment_id: current_audio_segment_id
        )
      end
      
      Rails.logger.info "Export completed successfully for user #{@user.id}: #{s3_key}"
      { s3_key: s3_key, file_size: file_size, file_count: file_count }
      
    rescue => e
      Rails.logger.error "Export failed for user #{@user.id}: #{e.message}"
      @export_record&.update!(status: 'failed')
      cleanup_directory(export_dir)
      raise e
    end
  end

  private

  def create_export_directory
    export_dir = Rails.root.join('tmp', "user_export_#{@user.id}_#{@export_timestamp}")
    FileUtils.mkdir_p(export_dir)
    FileUtils.mkdir_p(export_dir.join('data'))
    FileUtils.mkdir_p(export_dir.join('audio_files'))
    FileUtils.mkdir_p(export_dir.join('logs'))
    export_dir
  end

  def generate_csv_files(export_dir)
    data_dir = export_dir.join('data')
    csv_files = {}

    # Users CSV
    csv_files['users.csv'] = generate_users_csv(data_dir)
    
    # Projects CSV
    csv_files['projects.csv'] = generate_projects_csv(data_dir)
    
    # Questions CSV (includes answers)
    csv_files['questions.csv'] = generate_questions_csv(data_dir)
    
    # Audio Segments CSV
    csv_files['audio_segments.csv'] = generate_audio_segments_csv(data_dir)
    
    # Transcripts CSV
    csv_files['transcripts.csv'] = generate_transcripts_csv(data_dir)
    
    # Feedbacks CSV
    csv_files['feedbacks.csv'] = generate_feedbacks_csv(data_dir)
    
    # Device Logs CSV
    csv_files['device_logs.csv'] = generate_device_logs_csv(data_dir)
    
    # Advisor Interactions CSV
    csv_files['advisor_interactions.csv'] = generate_advisor_interactions_csv(data_dir)

    Rails.logger.info "Generated #{csv_files.size} CSV files for user #{@user.id}"
    csv_files
  end

  def generate_users_csv(data_dir)
    file_path = data_dir.join('users.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << ['id', 'email', 'interests', 'admin', 'created_at', 'updated_at']
      csv << [
        @user.id,
        @user.email,
        @user.interests&.join(';'),
        @user.admin?,
        @user.created_at,
        @user.updated_at
      ]
    end
    file_path
  end

  def generate_projects_csv(data_dir)
    file_path = data_dir.join('projects.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'title', 'status', 'topic', 'is_speech_interview', 
        'voice_id', 'speech_rate', 'interview_length', 'question_count',
        'created_at', 'updated_at', 'last_modified_at', 'last_accessed_at'
      ]
      
      @user.projects.find_each do |project|
        csv << [
          project.id,
          project.title,
          project.status,
          project.topic,
          project.is_speech_interview,
          project.voice_id,
          project.speech_rate,
          project.interview_length,
          project.question_count,
          project.created_at,
          project.updated_at,
          project.last_modified_at,
          project.last_accessed_at
        ]
      end
    end
    file_path
  end

  def generate_questions_csv(data_dir)
    file_path = data_dir.join('questions.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'project_id', 'chapter_title', 'section_title', 
        'question_text', 'question_order', 'is_follow_up', 'parent_question_id',
        'has_response', 'transcribed_response', 'created_at', 'updated_at'
      ]
      
      @user.projects.includes(:questions).find_each do |project|
        project.questions.find_each do |question|
          csv << [
            question.id,
            project.id,
            question.section&.chapter&.title,
            question.section&.title,
            question.text,
            question.order,
            question.parent_question_id.present?,
            question.parent_question_id,
            question.has_response?,
            question.transcribed_response,
            question.created_at,
            question.updated_at
          ]
        end
      end
    end
    file_path
  end

  def generate_audio_segments_csv(data_dir)
    file_path = data_dir.join('audio_segments.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'project_id', 'question_id', 'file_name', 'mime_type',
        'duration_seconds', 's3_url', 'upload_status', 'transcription_text',
        'created_at', 'updated_at'
      ]
      
      @user.projects.includes(:audio_segments).find_each do |project|
        project.audio_segments.find_each do |segment|
          csv << [
            segment.id,
            project.id,
            segment.question_id,
            segment.file_name,
            segment.mime_type,
            segment.duration_seconds,
            segment.s3_url,
            segment.upload_status,
            segment.transcription_text,
            segment.created_at,
            segment.updated_at
          ]
        end
      end
    end
    file_path
  end

  def generate_transcripts_csv(data_dir)
    file_path = data_dir.join('transcripts.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'project_id', 'status', 'raw_content', 'edited_content',
        'created_at', 'updated_at'
      ]
      
      @user.projects.includes(:transcript).find_each do |project|
        if project.transcript
          transcript = project.transcript
          csv << [
            transcript.id,
            project.id,
            transcript.status,
            transcript.raw_content,
            transcript.edited_content,
            transcript.created_at,
            transcript.updated_at
          ]
        end
      end
    end
    file_path
  end

  def generate_feedbacks_csv(data_dir)
    file_path = data_dir.join('feedbacks.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'feedback_text', 'feedback_type', 'email', 'resolved',
        'admin_notes', 'created_at', 'updated_at'
      ]
      
      @user.feedbacks.find_each do |feedback|
        csv << [
          feedback.id,
          feedback.feedback_text,
          feedback.feedback_type,
          feedback.email,
          feedback.resolved,
          feedback.admin_notes,
          feedback.created_at,
          feedback.updated_at
        ]
      end
    end
    file_path
  end

  def generate_device_logs_csv(data_dir)
    file_path = data_dir.join('device_logs.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'device_id', 'build_version', 'os_version', 'log_type',
        's3_url', 'uploaded_at', 'created_at', 'updated_at'
      ]
      
      @user.device_logs.find_each do |log|
        csv << [
          log.id,
          log.device_id,
          log.build_version,
          log.os_version,
          log.log_type,
          log.s3_url,
          log.uploaded_at,
          log.created_at,
          log.updated_at
        ]
      end
    end
    file_path
  end

  def generate_advisor_interactions_csv(data_dir)
    file_path = data_dir.join('advisor_interactions.csv')
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'project_id', 'advisor_id', 'question', 'response', 
        'status', 'created_at', 'updated_at'
      ]
      
      # Check if advisor_interactions association exists
      if @user.projects.first&.respond_to?(:advisor_interactions)
        @user.projects.includes(:advisor_interactions).find_each do |project|
          project.advisor_interactions.find_each do |interaction|
            csv << [
              interaction.id,
              project.id,
              interaction.advisor_id,
              interaction.question,
              interaction.response,
              interaction.status,
              interaction.created_at,
              interaction.updated_at
            ]
          end
        end
      else
        # Association doesn't exist, just write headers
        Rails.logger.info "AdvisorInteraction model not found, skipping advisor interactions export"
      end
    end
    file_path
  rescue => e
    Rails.logger.warn "Failed to generate advisor interactions CSV: #{e.message}"
    # Create empty file with headers
    CSV.open(file_path, 'w') do |csv|
      csv << [
        'id', 'project_id', 'advisor_id', 'question', 'response', 
        'status', 'created_at', 'updated_at'
      ]
    end
    file_path
  end

  def collect_s3_files(export_dir)
    Rails.logger.info "Collecting S3 files for user #{@user.id}"
    s3_files = {}
    
    # Get all audio segments
    audio_count = collect_audio_files(export_dir)
    s3_files['audio_files'] = "#{audio_count} audio files"
    
    # Get device logs if any
    log_count = collect_device_log_files(export_dir)  
    s3_files['device_logs'] = "#{log_count} log files"
    
    Rails.logger.info "Collected #{audio_count} audio files and #{log_count} log files"
    s3_files
  end

  def collect_audio_files(export_dir)
    audio_dir = export_dir.join('audio_files')
    count = 0
    
    @user.projects.includes(:audio_segments).find_each do |project|
      project.audio_segments.where.not(s3_url: nil).find_each do |segment|
        begin
          if download_s3_file(segment.s3_url, audio_dir, "project_#{project.id}_#{segment.file_name}")
            count += 1
          end
        rescue => e
          Rails.logger.warn "Failed to download audio file #{segment.s3_url}: #{e.message}"
        end
      end
    end
    
    count
  end

  def collect_device_log_files(export_dir)
    logs_dir = export_dir.join('logs')
    count = 0
    
    @user.device_logs.where.not(s3_url: nil).find_each do |log|
      begin
        filename = "device_log_#{log.id}_#{log.device_id}.txt"
        if download_s3_file(log.s3_url, logs_dir, filename)
          count += 1
        end
      rescue => e
        Rails.logger.warn "Failed to download device log #{log.s3_url}: #{e.message}"
      end
    end
    
    count
  end

  def download_s3_file(s3_url, target_dir, filename)
    return false if s3_url.blank?
    
    begin
      # Parse S3 URL to get bucket and key
      uri = URI.parse(s3_url)
      
      if uri.host&.include?('amazonaws.com')
        # Extract bucket and key from S3 URL
        path_parts = uri.path[1..-1].split('/', 2)  # Remove leading slash
        bucket = path_parts[0] || uri.host.split('.').first
        key = path_parts[1] || uri.path[1..-1]
        
        s3_client = Aws::S3::Client.new
        target_path = target_dir.join(filename)
        
        s3_client.get_object(bucket: bucket, key: key, response_target: target_path.to_s)
        true
      else
        # For non-S3 URLs, try direct HTTP download
        require 'open-uri'
        target_path = target_dir.join(filename)
        File.open(target_path, 'wb') do |file|
          URI.open(s3_url) { |data| file.write(data.read) }
        end
        true
      end
    rescue => e
      Rails.logger.error "Failed to download file #{s3_url}: #{e.message}"
      false
    end
  end

  def create_readme_file(export_dir, csv_files, s3_categories)
    readme_path = export_dir.join('README.txt')
    File.open(readme_path, 'w') do |f|
      f.puts "=== INKRA DATA EXPORT ==="
      f.puts "Export created: #{Time.current}"
      f.puts "User ID: #{@user.id}"
      f.puts "User Email: #{@user.email}"
      f.puts ""
      f.puts "This export contains all your data from Inkra:"
      f.puts ""
      f.puts "DATA FILES (CSV format):"
      csv_files.each { |filename| f.puts "  - #{filename}" }
      f.puts ""
      f.puts "AUDIO FILES:"
      f.puts "  - All your interview recordings organized by project"
      f.puts ""
      f.puts "LOG FILES:"
      f.puts "  - Device logs and crash reports (if any)"
      f.puts ""
      f.puts "CSV FILE DESCRIPTIONS:"
      f.puts "  - users.csv: Your account information and preferences"
      f.puts "  - projects.csv: All your interview projects and metadata"
      f.puts "  - questions.csv: All interview questions and your answers"
      f.puts "  - audio_segments.csv: Metadata about your audio recordings"
      f.puts "  - transcripts.csv: Text transcriptions of your interviews"
      f.puts "  - feedbacks.csv: Any feedback you've provided to Inkra"
      f.puts "  - device_logs.csv: Technical logs from your device"
      f.puts "  - advisor_interactions.csv: Your interactions with AI advisors"
      f.puts ""
      f.puts "IMPORT INSTRUCTIONS:"
      f.puts "  - CSV files can be opened in Excel, Google Sheets, or any spreadsheet app"
      f.puts "  - Audio files are in their original format (usually M4A or MP3)"
      f.puts "  - All timestamps are in UTC format"
      f.puts ""
      f.puts "If you have questions about this export, contact support@inkra.app"
      f.puts ""
      f.puts "Thank you for using Inkra to capture your stories!"
    end
    readme_path
  end

  def create_zip_file(export_dir)
    zip_filename = "user_#{@user.id}_export_#{@export_timestamp}.zip"
    zip_path = Rails.root.join('tmp', zip_filename)
    
    Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
      Dir.glob(File.join(export_dir, '**', '*')).each do |file|
        next if File.directory?(file)
        
        # Get relative path from export directory
        relative_path = Pathname.new(file).relative_path_from(Pathname.new(export_dir.to_s))
        zipfile.add(relative_path.to_s, file)
      end
    end
    
    zip_path
  end

  def upload_to_s3(zip_file_path)
    return nil, 0 unless zip_file_path && File.exist?(zip_file_path)
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    s3_key = "user-exports/user_#{@user.id}_export_#{timestamp}.zip"
    
    # Get S3 client
    s3_client = Aws::S3::Client.new
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
    
    file_size = File.size(zip_file_path)
    
    File.open(zip_file_path, 'rb') do |file|
      s3_client.put_object(
        bucket: bucket_name,
        key: s3_key,
        body: file,
        content_type: 'application/zip',
        metadata: {
          'user-id' => @user.id.to_s,
          'export-created-at' => Time.current.iso8601
        }
      )
    end
    
    [s3_key, file_size]
  rescue => e
    Rails.logger.error "Failed to upload export to S3: #{e.message}"
    raise "Failed to upload export file to cloud storage"
  end

  def cleanup_directory(export_dir)
    FileUtils.rm_rf(export_dir) if export_dir && Dir.exist?(export_dir)
  rescue => e
    Rails.logger.warn "Failed to cleanup export directory #{export_dir}: #{e.message}"
  end
end