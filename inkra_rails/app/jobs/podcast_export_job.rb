require 'open3'
require 'tempfile'

class PodcastExportJob < ApplicationJob
  include Sidekiq::Status::Worker

  queue_as :default
  sidekiq_options retry: 3

  def perform(project_id, user_id)
    total 100 # Set total progress steps

    @project = Project.find(project_id)
    @user = User.find(user_id)
    
    Rails.logger.info "Starting podcast export for project #{project_id}"
    store current_step: "Initializing podcast export"
    
    # Get all audio segments ordered by question order
    audio_segments = get_ordered_audio_segments
    
    if audio_segments.empty?
      store error: "No audio segments found for project"
      raise "No audio segments available for export"
    end

    at 10, "Found #{audio_segments.count} audio segments"
    Rails.logger.info "Found #{audio_segments.count} audio segments for project #{project_id}"

    # Download audio files from S3
    local_files = download_audio_files(audio_segments)
    at 40, "Downloaded audio files"

    # Create podcast using FFmpeg
    podcast_file = create_podcast(local_files)
    at 80, "Created podcast file"

    # Upload to S3 and create shareable URL
    result = upload_podcast_to_s3(podcast_file)
    at 90, "Uploaded to S3"

    # Store results for retrieval
    store download_url: result[:download_url]
    store filename: result[:filename] 
    store file_size: result[:file_size]
    store duration: result[:duration]

    at 100, "Podcast export completed"
    Rails.logger.info "Completed podcast export for project #{project_id}"

  ensure
    # Clean up temporary files
    cleanup_temp_files
  end

  private

  def get_ordered_audio_segments
    # Get audio segments ordered by question order within each section/chapter
    @project.audio_segments
      .joins(question: { section: :chapter })
      .where.not(audio_file_key: nil)
      .order('chapters.order ASC, sections.order ASC, questions.order ASC')
      .includes(question: { section: :chapter })
  end

  def download_audio_files(audio_segments)
    store current_step: "Downloading audio files from S3"
    local_files = []
    s3_service = S3Service.new(@user)
    
    audio_segments.each_with_index do |segment, index|
      Rails.logger.info "Downloading segment #{index + 1}/#{audio_segments.count}: #{segment.audio_file_key}"
      
      # Create temporary file for this segment
      temp_file = Tempfile.new(['segment', '.m4a'])
      
      begin
        # Download from S3
        s3_service.download_audio_segment(segment.audio_file_key, temp_file.path)
        
        local_files << {
          file: temp_file,
          path: temp_file.path,
          segment: segment,
          question_text: segment.question.text
        }
        
        # Track temp files for cleanup
        @temp_files ||= []
        @temp_files << temp_file
        
      rescue => e
        Rails.logger.error "Failed to download segment #{segment.id}: #{e.message}"
        temp_file.close
        temp_file.unlink
        # Continue with other segments rather than failing completely
      end
      
      # Update progress (30% of total work is downloading)
      progress = 10 + ((index + 1).to_f / audio_segments.count * 30)
      at progress.round, "Downloaded #{index + 1}/#{audio_segments.count} files"
    end
    
    Rails.logger.info "Downloaded #{local_files.count}/#{audio_segments.count} audio files"
    local_files
  end

  def create_podcast(local_files)
    store current_step: "Stitching audio files together"
    Rails.logger.info "Creating podcast from #{local_files.count} audio segments"
    
    # Create output temporary file
    output_file = Tempfile.new(['podcast', '.m4a'])
    @temp_files ||= []
    @temp_files << output_file
    
    if local_files.count == 1
      # If only one file, just copy it
      File.copy(local_files.first[:path], output_file.path)
    else
      # Use FFmpeg to concatenate files
      concat_files_with_ffmpeg(local_files, output_file.path)
    end
    
    Rails.logger.info "Created podcast file: #{output_file.path}"
    output_file
  end

  def concat_files_with_ffmpeg(local_files, output_path)
    # Create a temporary file list for FFmpeg concat demuxer
    concat_list = Tempfile.new(['concat_list', '.txt'])
    @temp_files ||= []
    @temp_files << concat_list
    
    # Write file list in FFmpeg concat format
    local_files.each do |file_info|
      # Escape single quotes and backslashes for FFmpeg
      escaped_path = file_info[:path].gsub("'", "'\\\\''").gsub("\\", "\\\\")
      concat_list.puts "file '#{escaped_path}'"
    end
    concat_list.close
    
    # Build FFmpeg command for concatenation
    cmd = [
      'ffmpeg',
      '-f', 'concat',
      '-safe', '0',
      '-i', concat_list.path,
      '-c', 'copy',  # Copy streams without re-encoding for speed
      '-y',  # Overwrite output file
      output_path
    ]
    
    Rails.logger.info "Running FFmpeg command: #{cmd.join(' ')}"
    
    # Execute FFmpeg command
    stdout, stderr, status = Open3.capture3(*cmd)
    
    unless status.success?
      error_msg = "FFmpeg failed with status #{status.exitstatus}: #{stderr}"
      Rails.logger.error error_msg
      Rails.logger.error "FFmpeg stdout: #{stdout}"
      store error: error_msg
      raise error_msg
    end
    
    Rails.logger.info "FFmpeg concatenation completed successfully"
    Rails.logger.debug "FFmpeg output: #{stderr}" if stderr.present?
  end

  def upload_podcast_to_s3(podcast_file)
    store current_step: "Uploading podcast to S3"
    
    # Generate filename
    title_part = @project.title.parameterize.underscore[0..14]  # First 15 characters
    date_part = Time.current.strftime('%Y%m%d')
    filename = "#{title_part}_#{date_part}.m4a"
    
    # Get file info
    file_size = File.size(podcast_file.path)
    duration = get_audio_duration(podcast_file.path)
    
    Rails.logger.info "Uploading podcast file: #{filename} (#{file_size} bytes, #{duration} seconds)"
    
    # Upload to S3
    s3_service = S3Service.new(@user)
    upload_result = s3_service.store_podcast_export(
      file_path: podcast_file.path,
      filename: filename,
      project_id: @project.id,
      content_type: 'audio/mp4'
    )
    
    Rails.logger.info "Uploaded podcast to S3: #{upload_result[:download_url]}"
    
    {
      download_url: upload_result[:download_url],
      filename: filename,
      file_size: file_size,
      duration: format_duration(duration)
    }
  end

  def get_audio_duration(file_path)
    cmd = ['ffprobe', '-v', 'quiet', '-show_entries', 'format=duration', '-of', 'csv=p=0', file_path]
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if status.success? && stdout.present?
      stdout.strip.to_f.round(2)
    else
      Rails.logger.warn "Could not determine audio duration: #{stderr}"
      0.0
    end
  end

  def format_duration(seconds)
    return "0 seconds" if seconds.nil? || seconds == 0
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remaining_seconds = (seconds % 60).round
    
    parts = []
    parts << "#{hours.to_i} hour#{'s' if hours != 1}" if hours >= 1
    parts << "#{minutes.to_i} minute#{'s' if minutes != 1}" if minutes >= 1
    parts << "#{remaining_seconds} second#{'s' if remaining_seconds != 1}" if remaining_seconds > 0 || parts.empty?
    
    parts.join(", ")
  end

  def cleanup_temp_files
    return unless @temp_files
    
    @temp_files.each do |temp_file|
      begin
        temp_file.close unless temp_file.closed?
        temp_file.unlink if File.exist?(temp_file.path)
      rescue => e
        Rails.logger.warn "Failed to cleanup temp file: #{e.message}"
      end
    end
    
    Rails.logger.info "Cleaned up #{@temp_files.count} temporary files"
  end
end