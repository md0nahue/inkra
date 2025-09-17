Rails.application.config.after_initialize do
  # Only run in production or when explicitly requested
  if Rails.env.production? || ENV['SYNC_PRESET_QUESTIONS'] == 'true'
    Rails.logger.info "Syncing preset questions on startup..."
    
    begin
      result = PresetQuestionsImporter.import_all
      Rails.logger.info "Preset questions sync completed: #{result[:imported]} imported, #{result[:updated]} updated"
      
      if result[:errors].any?
        Rails.logger.warn "Preset questions sync had errors: #{result[:errors].join(', ')}"
      end
    rescue => e
      Rails.logger.error "Failed to sync preset questions on startup: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end