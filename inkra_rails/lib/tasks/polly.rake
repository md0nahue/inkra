namespace :polly do
  desc 'Generate demo audio files for all Polly voices'
  task generate_demos: :environment do
    puts "🎤 Starting Polly demo generation..."
    
    begin
      Aws::PollyDemoService.generate_all_demos
      puts "✅ Successfully generated demos for all voices"
    rescue => e
      puts "❌ Failed to generate demos: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  desc 'List all available demo URLs'
  task list_demos: :environment do
    puts "🎤 Available Polly demo URLs:"
    
    demos = Aws::PollyDemoService.get_all_demo_urls
    
    if demos.any?
      demos.each do |voice_id, url|
        puts "  #{voice_id}: #{url}"
      end
    else
      puts "  No demos found. Run 'rake polly:generate_demos' first."
    end
  end
end