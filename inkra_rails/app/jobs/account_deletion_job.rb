class AccountDeletionJob < ApplicationJob
  queue_as :default

  def perform(user_id, feedback_data = {})
    Rails.logger.info "Starting account deletion for user #{user_id}"

    user = User.find_by(id: user_id)
    unless user
      Rails.logger.warn "User #{user_id} not found for deletion - may have been already deleted"
      return
    end

    begin
      # Step 1: Clean up all S3 files first (before deleting database records)
      cleanup_user_s3_data(user_id)
      
      # Step 2: Delete all database records (cascading deletes via associations)
      user_email = user.email
      user.destroy!
      
      # Step 3: Send confirmation email
      UserDataExportMailer.account_deleted(user_email, feedback_data).deliver_now
      
      Rails.logger.info "Account deletion completed successfully for user #{user_id}"
      
    rescue => e
      Rails.logger.error "Account deletion failed for user #{user_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Try to send failure notification if user still exists
      if user&.persisted?
        UserDataExportMailer.deletion_failed(user.email, e.message).deliver_now rescue nil
      end
      
      # Re-raise to mark job as failed
      raise e
    end
  end

  private

  def cleanup_user_s3_data(user_id)
    Rails.logger.info "Starting S3 cleanup for user #{user_id}"
    
    s3_client = Aws::S3::Client.new
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
    
    # Define all S3 prefixes that contain user data
    user_prefixes = [
      "audio-segments/user-#{user_id}/",
      "device-logs/user-#{user_id}/", 
      "exports/user-#{user_id}/",
      "user-exports/user_#{user_id}_",  # Data export zips
      # Add any other user-specific S3 prefixes here
    ]
    
    total_deleted = 0
    
    user_prefixes.each do |prefix|
      begin
        deleted_count = delete_objects_by_prefix(s3_client, bucket_name, prefix)
        total_deleted += deleted_count
        Rails.logger.info "Deleted #{deleted_count} objects with prefix '#{prefix}'"
      rescue => e
        Rails.logger.error "Failed to delete objects with prefix '#{prefix}': #{e.message}"
        # Continue with other prefixes even if one fails
      end
    end
    
    Rails.logger.info "S3 cleanup completed for user #{user_id}. Total objects deleted: #{total_deleted}"
    
  rescue => e
    Rails.logger.error "S3 cleanup failed for user #{user_id}: #{e.message}"
    # Don't fail the entire deletion process if S3 cleanup fails
    # The database cleanup is more critical
  end

  def delete_objects_by_prefix(s3_client, bucket_name, prefix)
    deleted_count = 0
    continuation_token = nil
    
    loop do
      # List objects with the given prefix
      list_params = {
        bucket: bucket_name,
        prefix: prefix,
        max_keys: 1000
      }
      list_params[:continuation_token] = continuation_token if continuation_token
      
      response = s3_client.list_objects_v2(list_params)
      
      # Break if no objects found
      break if response.contents.empty?
      
      # Prepare objects for batch deletion
      objects_to_delete = response.contents.map { |obj| { key: obj.key } }
      
      # Delete objects in batch
      unless objects_to_delete.empty?
        s3_client.delete_objects(
          bucket: bucket_name,
          delete: { objects: objects_to_delete }
        )
        deleted_count += objects_to_delete.size
      end
      
      # Check if there are more objects to process
      continuation_token = response.is_truncated? ? response.next_continuation_token : nil
      break unless continuation_token
    end
    
    deleted_count
  end
end