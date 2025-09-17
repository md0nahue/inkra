class DataExportJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    export_record = UserDataExport.find(export_id)
    user = export_record.user
    
    Rails.logger.info "Starting data export for user #{user.id}, export ID #{export_id}"

    export_service = UserDataExportService.new(user, export_record)
    
    begin
      # Generate the export and update the record
      result = export_service.create_complete_export
      
      Rails.logger.info "Data export completed successfully for user #{user.id}"
      Rails.logger.info "Export details: #{result[:file_count]} files, #{export_record.formatted_file_size}"
      
    rescue => e
      Rails.logger.error "Data export failed for user #{user.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Record will be updated to 'failed' status by the service
      raise e
    end
  end
end