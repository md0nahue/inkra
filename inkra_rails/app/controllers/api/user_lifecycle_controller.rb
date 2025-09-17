class Api::UserLifecycleController < ApplicationController
  before_action :set_user

  def export_user_data
    # Check if user can create a new export (weekly throttling)
    unless UserDataExport.can_create_new_export?(@user)
      last_export = @user.user_data_exports.recent.first
      days_remaining = 7 - ((Time.current - last_export.created_at) / 1.day).to_i
      
      render json: { 
        error: "You can only request one data export per week", 
        days_until_next_export: days_remaining,
        last_export_date: last_export.created_at
      }, status: :too_many_requests
      return
    end

    # Check if there's already a valid export available
    current_export = @user.user_data_exports.valid_exports.recent.first
    if current_export && !current_export.data_is_stale?
      render json: {
        message: "Current export is still valid and up to date",
        export_id: current_export.id,
        status: current_export.status,
        created_at: current_export.created_at,
        expires_at: current_export.expires_at,
        file_count: current_export.file_count,
        file_size: current_export.formatted_file_size
      }
      return
    end

    # Create new export record
    export_record = @user.user_data_exports.create!(status: 'pending')
    
    # Start background job
    DataExportJob.perform_later(export_record.id)
    
    render json: { 
      message: "Data export started. Check back here to see progress and download when ready.",
      export_id: export_record.id,
      status: export_record.status,
      created_at: export_record.created_at
    }
  rescue => e
    Rails.logger.error "Failed to start data export for user #{@user.id}: #{e.message}"
    render json: { error: "Failed to start data export" }, status: :internal_server_error
  end

  def delete_account
    feedback_text = params[:experience_description]
    improvements = params[:what_would_change]
    request_export = params[:request_export] == true
    
    if feedback_text.blank? || feedback_text.length < 10
      render json: { error: "Experience description is required (minimum 10 characters)" }, status: :bad_request
      return
    end

    # Save feedback before deletion
    feedback_data = {
      user_id: @user.id,
      user_email: @user.email,
      experience_description: feedback_text,
      what_would_change: improvements,
      requested_export: request_export,
      deletion_requested_at: Time.current,
      user_created_at: @user.created_at
    }

    # Save feedback to file for analysis
    save_deletion_feedback(feedback_data)

    # If export requested, do export first then deletion
    if request_export
      DataExportJob.perform_later(@user.id, @user.email)
      AccountDeletionJob.set(wait: 30.minutes).perform_later(@user.id, feedback_data)
      message = "Account deletion scheduled. Your data export will be sent first, then your account will be deleted in 30 minutes."
    else
      AccountDeletionJob.perform_later(@user.id, feedback_data)
      message = "Account deletion started. All your data will be permanently removed."
    end

    render json: { 
      message: message,
      deletion_scheduled: true,
      export_requested: request_export
    }
  rescue => e
    Rails.logger.error "Failed to start account deletion for user #{@user.id}: #{e.message}"
    render json: { error: "Failed to process account deletion request" }, status: :internal_server_error
  end

  def export_status
    current_export = @user.user_data_exports.recent.first
    
    if current_export.nil?
      render json: {
        user_id: @user.id,
        email: @user.email,
        has_export: false,
        message: "No data export found",
        can_create_new: UserDataExport.can_create_new_export?(@user)
      }
      return
    end

    response_data = {
      user_id: @user.id,
      email: @user.email,
      has_export: true,
      export_id: current_export.id,
      status: current_export.status,
      created_at: current_export.created_at,
      expires_at: current_export.expires_at,
      file_count: current_export.file_count,
      file_size: current_export.formatted_file_size,
      days_until_expiration: current_export.days_until_expiration,
      data_is_stale: current_export.data_is_stale?,
      can_create_new: UserDataExport.can_create_new_export?(@user)
    }

    # Add download URL if export is ready
    if current_export.ready_for_download?
      response_data[:download_url] = generate_signed_url(current_export.s3_key)
      response_data[:share_url] = generate_share_url(current_export.s3_key)
    end

    render json: response_data
  end

  private

  def set_user
    @user = current_user
    unless @user
      render json: { error: "Authentication required" }, status: :unauthorized
    end
  end

  def generate_signed_url(s3_key)
    return nil unless s3_key
    
    s3_client = Aws::S3::Client.new
    bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
    
    signer = Aws::S3::Presigner.new(client: s3_client)
    signer.presigned_url(
      :get_object,
      bucket: bucket_name,
      key: s3_key,
      expires_in: 1.hour.to_i  # Short-lived URLs for security
    )
  rescue => e
    Rails.logger.error "Failed to generate signed URL: #{e.message}"
    nil
  end

  def generate_share_url(s3_key)
    return nil unless s3_key
    
    # Create a mailto link with the download URL
    download_url = generate_signed_url(s3_key)
    return nil unless download_url
    
    subject = "My Inkra Data Export"
    body = "Here's my complete Inkra data export:\n\n#{download_url}\n\nThis link expires in 1 hour for security."
    
    "mailto:?subject=#{CGI.escape(subject)}&body=#{CGI.escape(body)}"
  end

  def save_deletion_feedback(feedback_data)
    feedback_dir = Rails.root.join('tmp', 'deletion_feedback')
    FileUtils.mkdir_p(feedback_dir)
    
    filename = "user_#{feedback_data[:user_id]}_deletion_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt"
    filepath = feedback_dir.join(filename)
    
    File.open(filepath, 'w') do |f|
      f.puts "=== INKRA ACCOUNT DELETION FEEDBACK ==="
      f.puts "User ID: #{feedback_data[:user_id]}"
      f.puts "Email: #{feedback_data[:user_email]}"
      f.puts "Account Created: #{feedback_data[:user_created_at]}"
      f.puts "Deletion Requested: #{feedback_data[:deletion_requested_at]}"
      f.puts "Requested Data Export: #{feedback_data[:requested_export] ? 'Yes' : 'No'}"
      f.puts
      f.puts "EXPERIENCE DESCRIPTION:"
      f.puts feedback_data[:experience_description]
      f.puts
      if feedback_data[:what_would_change].present?
        f.puts "WHAT WOULD YOU CHANGE:"
        f.puts feedback_data[:what_would_change]
      else
        f.puts "WHAT WOULD YOU CHANGE: (no response provided)"
      end
      f.puts
      f.puts "=== END FEEDBACK ==="
    end

    Rails.logger.info "Deletion feedback saved to #{filepath}"
  rescue => e
    Rails.logger.error "Failed to save deletion feedback: #{e.message}"
    # Don't fail the deletion process if feedback saving fails
  end
end