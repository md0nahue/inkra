require 'csv'

class PerformanceTracker
  include Singleton
  
  attr_reader :timings
  
  TRACKING_FILE = Rails.root.join('log', 'performance_metrics.csv')
  SUMMARY_FILE = Rails.root.join('log', 'performance_summary.md')
  
  def initialize
    @timings = {}
    @session_id = nil
    @mutex = Mutex.new
    ensure_csv_exists
  end
  
  def start_session(session_id)
    @mutex.synchronize do
      @session_id = session_id
      @timings[session_id] = {
        start_time: Time.current,
        events: [],
        total_duration: 0
      }
      Rails.logger.info "🚀 Performance tracking started for session: #{session_id}"
    end
  end
  
  def track_event(event_name, metadata = {})
    start_time = Time.current
    result = nil
    
    if block_given?
      result = yield
      end_time = Time.current
    else
      end_time = Time.current
    end
    
    # Only track performance data if we have an active session
    if @session_id
      duration_ms = ((end_time - start_time) * 1000).round(2)
      
      @mutex.synchronize do
        event_data = {
          name: event_name,
          start_time: start_time,
          end_time: end_time,
          duration_ms: duration_ms,
          metadata: metadata
        }
        
        @timings[@session_id][:events] << event_data if @timings[@session_id]
        
        # Log to Rails logger
        Rails.logger.info "⏱️ [#{@session_id}] #{event_name}: #{duration_ms}ms #{metadata.to_json}"
        
        # Append to CSV
        append_to_csv(event_data)
      end
    end
    
    result
  end
  
  def end_session
    return unless @session_id
    
    @mutex.synchronize do
      if session_data = @timings[@session_id]
        end_time = Time.current
        session_data[:end_time] = end_time
        session_data[:total_duration] = ((end_time - session_data[:start_time]) * 1000).round(2)
        
        # Generate summary
        generate_summary(session_data)
        
        # Log final summary
        Rails.logger.info "🏁 Session #{@session_id} completed in #{session_data[:total_duration]}ms"
      end
      
      @session_id = nil
    end
  end
  
  def get_session_summary(session_id = nil)
    session_id ||= @session_id
    return nil unless session_id && @timings[session_id]
    
    session_data = @timings[session_id]
    events = session_data[:events]
    
    {
      session_id: session_id,
      total_duration_ms: session_data[:total_duration] || 0,
      event_count: events.size,
      events_by_duration: events.sort_by { |e| -e[:duration_ms] },
      events_by_category: categorize_events(events),
      bottlenecks: identify_bottlenecks(events)
    }
  end
  
  private
  
  def ensure_csv_exists
    unless File.exist?(TRACKING_FILE)
      CSV.open(TRACKING_FILE, 'w') do |csv|
        csv << ['timestamp', 'session_id', 'event_name', 'duration_ms', 'metadata']
      end
    end
  end
  
  def append_to_csv(event_data)
    CSV.open(TRACKING_FILE, 'a') do |csv|
      csv << [
        event_data[:start_time].iso8601,
        @session_id,
        event_data[:name],
        event_data[:duration_ms],
        event_data[:metadata].to_json
      ]
    end
  rescue => e
    Rails.logger.error "Failed to write to performance CSV: #{e.message}"
  end
  
  def generate_summary(session_data)
    events = session_data[:events]
    
    summary = []
    summary << "# Performance Summary - Session #{@session_id}"
    summary << "**Generated at:** #{Time.current.iso8601}"
    summary << "**Total Duration:** #{session_data[:total_duration]}ms"
    summary << ""
    summary << "## Event Timeline"
    summary << ""
    summary << "| Event | Duration (ms) | Percentage | Details |"
    summary << "|-------|--------------|------------|---------|"
    
    total_duration = session_data[:total_duration] || 1
    
    events.sort_by { |e| e[:start_time] }.each do |event|
      percentage = ((event[:duration_ms] / total_duration) * 100).round(1)
      details = event[:metadata].empty? ? "-" : event[:metadata].to_json
      summary << "| #{event[:name]} | #{event[:duration_ms]} | #{percentage}% | #{details} |"
    end
    
    summary << ""
    summary << "## Performance Analysis"
    summary << ""
    
    # Identify bottlenecks
    bottlenecks = identify_bottlenecks(events)
    if bottlenecks.any?
      summary << "### ⚠️ Bottlenecks Detected"
      summary << ""
      bottlenecks.each do |bottleneck|
        summary << "- **#{bottleneck[:name]}**: #{bottleneck[:duration_ms]}ms (#{bottleneck[:percentage]}% of total time)"
        if bottleneck[:name].include?('say_command') || bottleneck[:name].include?('polly')
          summary << "  - 💡 Audio generation is a major bottleneck. Consider:"
          summary << "    - Pre-generating audio for common questions"
          summary << "    - Using faster TTS voices"
          summary << "    - Implementing audio caching"
        elsif bottleneck[:name].include?('api') || bottleneck[:name].include?('network')
          summary << "  - 💡 Network latency detected. Consider:"
          summary << "    - Batch API requests"
          summary << "    - Implement request caching"
          summary << "    - Use connection pooling"
        elsif bottleneck[:name].include?('database') || bottleneck[:name].include?('query')
          summary << "  - 💡 Database performance issue. Consider:"
          summary << "    - Adding database indexes"
          summary << "    - Optimizing queries"
          summary << "    - Implementing query caching"
        end
      end
      summary << ""
    end
    
    # Categorize events
    categories = categorize_events(events)
    summary << "### 📊 Time by Category"
    summary << ""
    summary << "| Category | Total Time (ms) | Event Count |"
    summary << "|----------|----------------|-------------|"
    
    categories.each do |category, data|
      summary << "| #{category} | #{data[:total_ms]} | #{data[:count]} |"
    end
    
    summary << ""
    summary << "## Recommendations"
    summary << ""
    
    # Generate recommendations based on data
    if session_data[:total_duration] > 5000
      summary << "- ⚠️ **Total load time exceeds 5 seconds** - Users may experience frustration"
    end
    
    audio_events = events.select { |e| e[:name].downcase.include?('audio') || e[:name].downcase.include?('polly') || e[:name].downcase.include?('say') }
    if audio_events.any?
      audio_total = audio_events.sum { |e| e[:duration_ms] }
      audio_percentage = ((audio_total / total_duration) * 100).round(1)
      if audio_percentage > 40
        summary << "- 🔊 **Audio generation takes #{audio_percentage}% of total time**"
        summary << "  - Consider pre-generating audio during project creation"
        summary << "  - Implement progressive loading (start interview while audio generates)"
      end
    end
    
    api_events = events.select { |e| e[:name].downcase.include?('api') || e[:name].downcase.include?('request') }
    if api_events.size > 5
      summary << "- 🌐 **Multiple API calls detected (#{api_events.size} calls)**"
      summary << "  - Consider batching API requests"
      summary << "  - Implement request parallelization"
    end
    
    # Write to file
    File.write(SUMMARY_FILE, summary.join("\n"))
    
    # Also append to a historical summary file
    historical_file = Rails.root.join('log', "performance_history_#{Date.current.strftime('%Y%m%d')}.md")
    File.open(historical_file, 'a') do |f|
      f.puts "\n---\n"
      f.puts summary.join("\n")
    end
    
    Rails.logger.info "📊 Performance summary written to #{SUMMARY_FILE}"
  rescue => e
    Rails.logger.error "Failed to generate performance summary: #{e.message}"
  end
  
  def categorize_events(events)
    categories = {}
    
    events.each do |event|
      category = determine_category(event[:name])
      categories[category] ||= { total_ms: 0, count: 0, events: [] }
      categories[category][:total_ms] += event[:duration_ms]
      categories[category][:count] += 1
      categories[category][:events] << event
    end
    
    categories
  end
  
  def determine_category(event_name)
    name = event_name.downcase
    
    return 'Audio Generation' if name.include?('audio') || name.include?('polly') || name.include?('say') || name.include?('speech')
    return 'Database' if name.include?('database') || name.include?('query') || name.include?('activerecord')
    return 'API/Network' if name.include?('api') || name.include?('request') || name.include?('http')
    return 'File I/O' if name.include?('file') || name.include?('s3') || name.include?('upload') || name.include?('download')
    return 'Processing' if name.include?('process') || name.include?('generate') || name.include?('compute')
    
    'Other'
  end
  
  def identify_bottlenecks(events, threshold_percentage = 20)
    return [] if events.empty?
    
    total_duration = events.sum { |e| e[:duration_ms] }
    return [] if total_duration == 0
    
    bottlenecks = []
    
    events.each do |event|
      percentage = ((event[:duration_ms] / total_duration) * 100).round(1)
      if percentage >= threshold_percentage
        bottlenecks << {
          name: event[:name],
          duration_ms: event[:duration_ms],
          percentage: percentage,
          metadata: event[:metadata]
        }
      end
    end
    
    bottlenecks.sort_by { |b| -b[:duration_ms] }
  end
end