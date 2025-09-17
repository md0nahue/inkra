require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  
  # Filter sensitive data
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV['GEMINI_API_KEY'] }
  
  # Filter API key from URLs
  config.filter_sensitive_data('<FILTERED_API_KEY>') do |interaction|
    if interaction.request.uri.include?('key=')
      key_param = interaction.request.uri.match(/key=([^&]+)/)
      key_param[1] if key_param
    end
  end
  
  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key), :body]
  }
end