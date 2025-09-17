Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for tracing.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # Set profiles_sample_rate to profile 100%
  # of sampled transactions.
  # We recommend adjusting this value in production.
  config.profiles_sample_rate = Rails.env.production? ? 0.1 : 1.0

  # Filter out sensitive data
  config.before_send = lambda do |event, hint|
    # Filter out requests to health check endpoint
    if event.request&.url&.include?('/up')
      nil
    else
      event
    end
  end

  # Set release version
  config.release = ENV['HEROKU_SLUG_COMMIT'] || `git rev-parse HEAD`.strip
end