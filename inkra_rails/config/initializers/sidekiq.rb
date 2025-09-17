# Custom broadcast logger class for dual output
class SidekiqBroadcastLogger
  def initialize
    # Ensure log directory exists
    log_dir = Rails.root.join('log')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    
    # Set up file logger with daily rotation
    @file_logger = Logger.new(Rails.root.join('log', 'sidekiq.log'), 'daily')
    @file_logger.level = Logger::INFO
    
    # Set up console logger
    @console_logger = Logger.new(STDOUT)
    @console_logger.level = Logger::INFO
    
    # Common formatter for both loggers
    formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    
    @file_logger.formatter = formatter
    @console_logger.formatter = formatter
  end
  
  # Delegate all logger methods to both loggers
  %w[debug info warn error fatal].each do |level|
    define_method(level) do |message = nil, &block|
      @file_logger.send(level, message, &block)
      @console_logger.send(level, message, &block)
    end
  end
  
  def add(severity, message = nil, progname = nil, &block)
    @file_logger.add(severity, message, progname, &block)
    @console_logger.add(severity, message, progname, &block)
  end
  
  def level=(level)
    @file_logger.level = level
    @console_logger.level = level
  end
  
  def level
    @console_logger.level
  end
  
  def formatter
    @console_logger.formatter
  end
  
  def formatter=(formatter)
    @file_logger.formatter = formatter
    @console_logger.formatter = formatter
  end
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Set up dual logging to file and terminal
  config.logger = SidekiqBroadcastLogger.new
  
  # Configure error reporting with Sentry
  config.error_handlers << proc do |ex, ctx_hash|
    Rails.logger.error "Sidekiq job failed: #{ex.message}"
    Rails.logger.error "Context: #{ctx_hash}"
    Rails.logger.error ex.backtrace.join("\n")
    
    # Report to Sentry if configured
    if defined?(Sentry)
      Sentry.capture_exception(ex, extra: ctx_hash)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure job retry logic
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    Rails.logger.error "Sidekiq job #{job['class']} died after all retries: #{ex.message}"
    
    # Handle specific job failures
    case job['class']
    when 'TranscriptionJob'
      handle_transcription_failure(job['args'][0], ex)
    when 'GenerateFollowupQuestionsJob'
      handle_followup_generation_failure(job['args'][0], ex)
    end
  end
end

def handle_transcription_failure(audio_segment_id, exception)
  audio_segment = AudioSegment.find_by(id: audio_segment_id)
  return unless audio_segment
  
  audio_segment.update!(upload_status: 'transcription_failed')
  Rails.logger.error "Marked audio segment #{audio_segment_id} as transcription_failed"
end

def handle_followup_generation_failure(audio_segment_id, exception)
  Rails.logger.error "Follow-up question generation failed for audio segment #{audio_segment_id}: #{exception.message}"
  
  audio_segment = AudioSegment.find_by(id: audio_segment_id)
  return unless audio_segment&.project
end