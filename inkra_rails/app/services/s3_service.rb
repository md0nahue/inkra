class S3Service
  def initialize(user)
    @user = user
  end

  def generate_upload_url(record_id:, record_type:, filename:, content_type: 'audio/mp4', expires_in: 3600)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_s3_key(record_id: record_id, record_type: record_type, filename: filename)
    
    Rails.logger.info "========== S3 UPLOAD URL GENERATION =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    Rails.logger.info "Content Type: #{content_type}"
    Rails.logger.info "User ID: #{@user.id}"
    Rails.logger.info "Record Type: #{record_type}"
    Rails.logger.info "Record ID: #{record_id}"
    Rails.logger.info "AWS Region: #{aws_region}"
    Rails.logger.info "AWS Access Key ID present: #{aws_access_key_id.present?}"
    Rails.logger.info "AWS Secret Key present: #{aws_secret_access_key.present?}"

    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )

      # Test bucket access
      begin
        s3_client.head_bucket(bucket: bucket_name)
        Rails.logger.info "✅ Bucket access verified"
      rescue => e
        Rails.logger.error "❌ Bucket access error: #{e.class} - #{e.message}"
      end
      
      presigner = Aws::S3::Presigner.new(client: s3_client)
      url = presigner.presigned_url(
        :put_object, 
        bucket: bucket_name, 
        key: key, 
        expires_in: expires_in,
        content_type: content_type
      )
      
      Rails.logger.info "✅ Generated presigned upload URL successfully"
      Rails.logger.info "URL (first 150 chars): #{url[0..150]}..."
      Rails.logger.info "========== END S3 UPLOAD URL GENERATION =========="
      
      {
        url: url,
        s3_url: "https://#{bucket_name}.s3.amazonaws.com/#{key}",
        key: key,
        bucket: bucket_name
      }
    rescue => e
      Rails.logger.error "❌ S3 UPLOAD URL GENERATION FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.first(5).join("\n")
      Rails.logger.error "========== END S3 UPLOAD URL GENERATION =========="
      
      # Return mock URL in development if S3 fails
      if Rails.env.development?
        Rails.logger.warn "🔄 Returning mock URL for development"
        {
          url: "https://mock-s3-upload-url.com/#{key}",
          s3_url: "https://#{bucket_name}.s3.amazonaws.com/#{key}",
          key: key,
          bucket: bucket_name
        }
      else
        raise e
      end
    end
  end

  def generate_playback_url(record_id:, record_type:, filename:, content_type: 'audio/mp4', expires_in: 3600)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_s3_key(record_id: record_id, record_type: record_type, filename: filename)

    s3_client = Aws::S3::Client.new(
      region: aws_region,
      access_key_id: aws_access_key_id,
      secret_access_key: aws_secret_access_key
    )
    
    presigner = Aws::S3::Presigner.new(client: s3_client)
    url = presigner.presigned_url(
      :get_object, 
      bucket: bucket_name, 
      key: key, 
      expires_in: expires_in,
      response_content_type: content_type
    )
    
    Rails.logger.info "Generated playback URL: #{url}"
    url
  end

  def download_audio_data(record_id:, record_type:, filename:)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_s3_key(record_id: record_id, record_type: record_type, filename: filename)
    
    Rails.logger.info "========== S3 AUDIO DOWNLOAD =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    Rails.logger.info "User ID: #{@user.id}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      response = s3_client.get_object(bucket: bucket_name, key: key)
      audio_data = response.body.read
      
      Rails.logger.info "✅ Successfully downloaded audio data (#{audio_data.bytesize} bytes)"
      Rails.logger.info "========== END S3 AUDIO DOWNLOAD =========="
      
      audio_data
    rescue => e
      Rails.logger.error "❌ S3 AUDIO DOWNLOAD FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "========== END S3 AUDIO DOWNLOAD =========="
      
      # Return nil so the calling code can handle the fallback
      nil
    end
  end

  def download_audio_to_file(record_id:, record_type:, filename:, target_path:)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_s3_key(record_id: record_id, record_type: record_type, filename: filename)
    
    Rails.logger.info "========== S3 AUDIO DOWNLOAD TO FILE =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    Rails.logger.info "Target Path: #{target_path}"
    Rails.logger.info "User ID: #{@user.id}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      s3_client.get_object(
        response_target: target_path,
        bucket: bucket_name,
        key: key
      )
      
      Rails.logger.info "✅ Successfully downloaded audio to file"
      Rails.logger.info "========== END S3 AUDIO DOWNLOAD TO FILE =========="
      
      true
    rescue => e
      Rails.logger.error "❌ S3 AUDIO DOWNLOAD TO FILE FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "========== END S3 AUDIO DOWNLOAD TO FILE =========="
      
      false
    end
  end

  # Store export file in S3 and return shareable URL
  def store_export_file(content:, filename:, project_id: nil, format:, expires_in: 7.days)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_export_s3_key(filename: filename, project_id: project_id, format: format)
    
    Rails.logger.info "========== S3 EXPORT FILE STORAGE =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    Rails.logger.info "Content Size: #{content.bytesize} bytes"
    Rails.logger.info "User ID: #{@user.id}"
    Rails.logger.info "Format: #{format}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      # Upload the content to S3
      s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: content,
        content_type: content_type_for_format(format),
        content_disposition: "attachment; filename=\"#{filename}\"",
        # Set expiration using object tagging or lifecycle policy
        expires: Time.current + expires_in
      )
      
      # Generate a presigned URL for sharing
      presigner = Aws::S3::Presigner.new(client: s3_client)
      share_url = presigner.presigned_url(
        :get_object,
        bucket: bucket_name,
        key: key,
        expires_in: expires_in.to_i,
        response_content_disposition: "attachment; filename=\"#{filename}\""
      )
      
      Rails.logger.info "✅ Successfully stored export file and generated share URL"
      Rails.logger.info "Share URL (first 150 chars): #{share_url[0..150]}..."
      Rails.logger.info "========== END S3 EXPORT FILE STORAGE =========="
      
      {
        share_url: share_url,
        s3_key: key,
        bucket: bucket_name,
        expires_at: Time.current + expires_in
      }
    rescue => e
      Rails.logger.error "❌ S3 EXPORT FILE STORAGE FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.first(5).join("\n")
      Rails.logger.error "========== END S3 EXPORT FILE STORAGE =========="
      
      # Return mock URL in development if S3 fails
      if Rails.env.development?
        Rails.logger.warn "🔄 Returning mock share URL for development"
        {
          share_url: "https://mock-s3-share-url.com/#{key}",
          s3_key: key,
          bucket: bucket_name,
          expires_at: Time.current + expires_in
        }
      else
        raise e
      end
    end
  end

  # Extract S3 key from full S3 URL
  def extract_s3_key_from_url(s3_url)
    uri = URI.parse(s3_url)
    uri.path.delete_prefix('/')
  end
  
  # Upload audio data directly to S3 (used by Polly service)
  def upload_audio_data(key, audio_stream)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    
    Rails.logger.info "========== S3 AUDIO DATA UPLOAD =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: audio_stream,
        content_type: 'audio/mp3'
      )
      
      Rails.logger.info "✅ Successfully uploaded audio data to S3"
      Rails.logger.info "========== END S3 AUDIO DATA UPLOAD =========="
      
      true
    rescue => e
      Rails.logger.error "❌ S3 AUDIO DATA UPLOAD FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "========== END S3 AUDIO DATA UPLOAD =========="
      
      raise e
    end
  end
  
  # Get presigned URL for a given S3 key
  def get_presigned_url(key, expires_in: 3600)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    
    s3_client = Aws::S3::Client.new(
      region: aws_region,
      access_key_id: aws_access_key_id,
      secret_access_key: aws_secret_access_key
    )
    
    presigner = Aws::S3::Presigner.new(client: s3_client)
    presigner.presigned_url(
      :get_object,
      bucket: bucket_name,
      key: key,
      expires_in: expires_in
    )
  end

  # Download audio segment using its S3 key to local file path
  def download_audio_segment(s3_key, local_file_path)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    
    Rails.logger.info "========== S3 AUDIO SEGMENT DOWNLOAD =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{s3_key}"
    Rails.logger.info "Target Path: #{local_file_path}"
    Rails.logger.info "User ID: #{@user.id}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      s3_client.get_object(
        response_target: local_file_path,
        bucket: bucket_name,
        key: s3_key
      )
      
      Rails.logger.info "✅ Successfully downloaded audio segment to file"
      Rails.logger.info "File size: #{File.size(local_file_path)} bytes"
      Rails.logger.info "========== END S3 AUDIO SEGMENT DOWNLOAD =========="
      
      true
    rescue => e
      Rails.logger.error "❌ S3 AUDIO SEGMENT DOWNLOAD FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "========== END S3 AUDIO SEGMENT DOWNLOAD =========="
      
      raise e
    end
  end

  # Store podcast export file in S3 and return download URL
  def store_podcast_export(file_path:, filename:, project_id:, content_type: 'audio/mp4', expires_in: 7.days)
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
    key = generate_podcast_s3_key(filename: filename, project_id: project_id)
    
    Rails.logger.info "========== S3 PODCAST EXPORT STORAGE =========="
    Rails.logger.info "Bucket: #{bucket_name}"
    Rails.logger.info "Key: #{key}"
    Rails.logger.info "File Path: #{file_path}"
    Rails.logger.info "File Size: #{File.size(file_path)} bytes"
    Rails.logger.info "User ID: #{@user.id}"
    Rails.logger.info "Content Type: #{content_type}"
    
    begin
      s3_client = Aws::S3::Client.new(
        region: aws_region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      
      # Upload the file to S3
      File.open(file_path, 'rb') do |file|
        s3_client.put_object(
          bucket: bucket_name,
          key: key,
          body: file,
          content_type: content_type,
          content_disposition: "attachment; filename=\"#{filename}\"",
          # Set expiration
          expires: Time.current + expires_in,
          metadata: {
            'user-id' => @user.id.to_s,
            'project-id' => project_id.to_s,
            'export-type' => 'podcast',
            'created-at' => Time.current.iso8601
          }
        )
      end
      
      # Generate a presigned URL for downloading
      presigner = Aws::S3::Presigner.new(client: s3_client)
      download_url = presigner.presigned_url(
        :get_object,
        bucket: bucket_name,
        key: key,
        expires_in: expires_in.to_i,
        response_content_disposition: "attachment; filename=\"#{filename}\"",
        response_content_type: content_type
      )
      
      Rails.logger.info "✅ Successfully stored podcast export and generated download URL"
      Rails.logger.info "Download URL (first 150 chars): #{download_url[0..150]}..."
      Rails.logger.info "========== END S3 PODCAST EXPORT STORAGE =========="
      
      {
        download_url: download_url,
        s3_key: key,
        bucket: bucket_name,
        expires_at: Time.current + expires_in
      }
    rescue => e
      Rails.logger.error "❌ S3 PODCAST EXPORT STORAGE FAILED"
      Rails.logger.error "Error Class: #{e.class}"
      Rails.logger.error "Error Message: #{e.message}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.first(5).join("\n")
      Rails.logger.error "========== END S3 PODCAST EXPORT STORAGE =========="
      
      # Return mock URL in development if S3 fails
      if Rails.env.development?
        Rails.logger.warn "🔄 Returning mock podcast URL for development"
        {
          download_url: "https://mock-s3-podcast-url.com/#{key}",
          s3_key: key,
          bucket: bucket_name,
          expires_at: Time.current + expires_in
        }
      else
        raise e
      end
    end
  end

  private

  def environment_prefix
    case Rails.env
    when 'production'
      'production/'
    when 'staging'
      'staging/'
    else
      'dev/'
    end
  end

  def generate_s3_key(record_id:, record_type:, filename:)
    prefix = environment_prefix
    case record_type.to_s.downcase
    when 'audiosegment', 'audio_segment'
      "#{prefix}audio_segments/#{record_id}/#{filename}"
    when 'logentry', 'log_entry', 'vibelog'
      "#{prefix}vibelog/#{@user.id}/#{record_id}_#{Time.current.to_i}.m4a"
    else
      "#{prefix}#{record_type.to_s.downcase}/#{@user.id}/#{record_id}/#{filename}"
    end
  end

  def generate_export_s3_key(filename:, project_id: nil, format:)
    prefix = environment_prefix
    timestamp = Time.current.to_i
    if project_id
      "#{prefix}exports/projects/#{@user.id}/#{project_id}/#{timestamp}_#{filename}"
    else
      "#{prefix}exports/vibelog/#{@user.id}/#{timestamp}_#{filename}"
    end
  end

  def generate_podcast_s3_key(filename:, project_id:)
    prefix = environment_prefix
    timestamp = Time.current.to_i
    "#{prefix}exports/podcasts/#{@user.id}/#{project_id}/#{timestamp}_#{filename}"
  end

  def content_type_for_format(format)
    case format.to_s.downcase
    when 'csv'
      'text/csv'
    when 'pdf'
      'application/pdf'
    when 'docx'
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    else
      'text/plain'
    end
  end

  def aws_region
    Rails.application.credentials.dig(:aws, :region) || ENV['AWS_REGION'] || 'us-east-1'
  end

  def aws_access_key_id
    Rails.application.credentials.dig(:aws, :access_key_id) || ENV['AWS_ACCESS_KEY_ID']
  end

  def aws_secret_access_key
    Rails.application.credentials.dig(:aws, :secret_access_key) || ENV['AWS_SECRET_ACCESS_KEY']
  end
end