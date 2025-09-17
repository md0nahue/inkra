class DeviceLog < ApplicationRecord
  belongs_to :user
  
  validates :device_id, presence: true
  validates :s3_url, presence: true
  validates :log_type, inclusion: { in: %w[crash manual automatic debug] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :crashes, -> { where(log_type: 'crash') }
  scope :for_device, ->(device_id) { where(device_id: device_id) }
  
  private
  
  def presigned_url(expires_in: 3600)
    return nil unless s3_url.present?
    
    s3 = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    bucket, key = parse_s3_url
    return nil unless bucket && key
    
    signer = Aws::S3::Presigner.new(client: s3)
    signer.presigned_url(:get_object, bucket: bucket, key: key, expires_in: expires_in)
  rescue StandardError => e
    Rails.logger.error "Failed to generate presigned URL: #{e.message}"
    nil
  end
  
  def parse_s3_url
    return [nil, nil] unless s3_url.present?
    
    if s3_url.start_with?('s3://')
      parts = s3_url.gsub('s3://', '').split('/', 2)
      [parts[0], parts[1]]
    elsif s3_url.start_with?('https://')
      uri = URI.parse(s3_url)
      bucket = uri.host.split('.').first
      key = uri.path[1..-1] # Remove leading slash
      [bucket, key]
    else
      [nil, nil]
    end
  end
end