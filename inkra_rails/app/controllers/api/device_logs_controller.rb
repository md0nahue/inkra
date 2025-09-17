class Api::DeviceLogsController < ApplicationController
  before_action :authenticate_user!
  
  # POST /api/device_logs/presigned_url
  def presigned_url
    expires_in = params[:expires_in] || 3600
    content_type = params[:content_type] || 'text/plain'
    
    # Generate unique key for the log file
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    device_id = params[:device_id] || 'unknown'
    log_type = params[:log_type] || 'manual'
    key = "device_logs/user_#{current_user.id}/#{device_id}/#{log_type}_#{timestamp}_#{SecureRandom.hex(4)}.log"
    
    # Generate presigned URL for upload
    s3 = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    bucket = ENV['S3_USER_CONTENT_BUCKET'] || 'inkra-user-content'
    
    signer = Aws::S3::Presigner.new(client: s3)
    presigned_url = signer.presigned_url(
      :put_object,
      bucket: bucket,
      key: key,
      expires_in: expires_in.to_i,
      content_type: content_type
    )
    
    # Create DeviceLog record
    device_log = current_user.device_logs.create!(
      s3_url: "s3://#{bucket}/#{key}",
      device_id: device_id,
      build_version: params[:build_version],
      os_version: params[:os_version],
      log_type: log_type
    )
    
    render json: {
      upload_url: presigned_url,
      log_id: device_log.id,
      s3_key: key,
      expires_at: Time.current + expires_in.to_i.seconds
    }
  rescue StandardError => e
    Rails.logger.error "Failed to generate presigned URL: #{e.message}"
    render json: { error: 'Failed to generate upload URL' }, status: :internal_server_error
  end
  
  # POST /api/device_logs/:id/confirm_upload
  def confirm_upload
    device_log = current_user.device_logs.find(params[:id])
    device_log.update!(uploaded_at: Time.current)
    
    render json: { success: true, log_id: device_log.id }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Log not found' }, status: :not_found
  end
  
  # GET /api/device_logs
  def index
    logs = current_user.device_logs
                       .recent
                       .page(params[:page])
                       .per(params[:per_page] || 20)
    
    render json: logs.map { |log|
      {
        id: log.id,
        device_id: log.device_id,
        build_version: log.build_version,
        os_version: log.os_version,
        log_type: log.log_type,
        uploaded_at: log.uploaded_at,
        created_at: log.created_at
      }
    }
  end
  
  # GET /api/device_logs/:id/download_url
  def download_url
    device_log = current_user.device_logs.find(params[:id])
    
    presigned_url = device_log.send(:presigned_url, expires_in: 3600)
    
    if presigned_url
      render json: { download_url: presigned_url, expires_in: 3600 }
    else
      render json: { error: 'Failed to generate download URL' }, status: :internal_server_error
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Log not found' }, status: :not_found
  end
end