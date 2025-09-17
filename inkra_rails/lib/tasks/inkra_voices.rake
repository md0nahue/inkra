namespace :inkra do
  desc 'Generate Inkra welcome phrases for 10 diverse voices'
  task generate_voices: :environment do
    puts "🌟 Starting Inkra voice welcome generation..."
    
    begin
      # Load and execute the InkraVoiceGenerator script
      load Rails.root.join('scripts', 'generate_inkra_voices.rb')
      
      generator = InkraVoiceGenerator.new
      results = generator.generate_all_inkra_voices
      
      puts "✅ Successfully generated Inkra welcomes for #{results.length} voices"
      
      # Display summary
      puts "\n📋 Generated Voice Summary:"
      results.each do |result|
        voice = result[:voice]
        puts "  • #{voice[:name]} (#{voice[:gender]}, #{voice[:language]})"
        puts "    URL: #{result[:s3_url]}"
        puts "    Phrase: #{result[:inkra_phrase].truncate(80)}"
        puts
      end
      
    rescue => e
      puts "❌ Failed to generate Inkra voices: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
      raise e
    end
  end

  desc 'List all available Inkra voice welcome URLs'
  task list_voices: :environment do
    puts "🌟 Available Inkra Voice Welcome URLs:"
    puts
    
    # Check S3 for existing Inkra welcome files
    begin
      s3_client = Aws::S3::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
      bucket_name = ENV['AWS_S3_BUCKET']
      
      response = s3_client.list_objects_v2({
        bucket: bucket_name,
        prefix: 'inkra_voice_welcomes/'
      })
      
      if response.contents.any?
        response.contents.each do |object|
          voice_id = File.basename(object.key, '_inkra_welcome.mp3').capitalize
          url = "https://#{bucket_name}.s3.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{object.key}"
          
          # Get metadata if available
          metadata_response = s3_client.head_object({
            bucket: bucket_name,
            key: object.key
          })
          
          voice_name = metadata_response.metadata['voice-name'] || voice_id
          voice_gender = metadata_response.metadata['voice-gender'] || 'Unknown'
          
          puts "  🎙️  #{voice_name} (#{voice_gender})"
          puts "      URL: #{url}"
          puts "      Generated: #{metadata_response.last_modified}"
          puts
        end
      else
        puts "  No Inkra voice welcomes found. Run 'rake inkra:generate_voices' first."
      end
      
    rescue => e
      puts "❌ Failed to list Inkra voices: #{e.message}"
      puts "Make sure AWS credentials and S3 bucket are configured correctly."
    end
  end

  desc 'Test playback of a specific Inkra voice (requires voice_id parameter)'
  task test_voice: :environment do
    voice_id = ENV['voice_id']
    
    unless voice_id
      puts "❌ Please specify a voice_id parameter:"
      puts "   rake inkra:test_voice voice_id=Matthew"
      exit 1
    end
    
    puts "🎵 Testing playback for voice: #{voice_id}"
    
    begin
      bucket_name = ENV['AWS_S3_BUCKET']
      s3_key = "inkra_voice_welcomes/#{voice_id.downcase}_inkra_welcome.mp3"
      url = "https://#{bucket_name}.s3.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{s3_key}"
      
      # Check if the file exists
      s3_client = Aws::S3::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
      s3_client.head_object({
        bucket: bucket_name,
        key: s3_key
      })
      
      puts "✅ Voice file found: #{url}"
      puts "🎧 You can test this URL in a browser or audio player"
      
    rescue Aws::S3::Errors::NotFound
      puts "❌ Voice file not found for #{voice_id}"
      puts "   Available voices: Matthew, Joanna, Arthur, Emma, Olivia, Brian, Ruth, Stephen, Aria, Gregory"
      puts "   Run 'rake inkra:generate_voices' to create voice files"
    rescue => e
      puts "❌ Error testing voice: #{e.message}"
    end
  end

  desc 'Clean up old Inkra voice welcome files'
  task cleanup: :environment do
    puts "🧹 Cleaning up old Inkra voice welcome files..."
    
    begin
      s3_client = Aws::S3::Client.new(region: ENV['AWS_REGION'] || 'us-east-1')
      bucket_name = ENV['AWS_S3_BUCKET']
      
      response = s3_client.list_objects_v2({
        bucket: bucket_name,
        prefix: 'inkra_voice_welcomes/'
      })
      
      if response.contents.any?
        puts "Found #{response.contents.count} Inkra voice files to delete"
        
        response.contents.each do |object|
          s3_client.delete_object({
            bucket: bucket_name,
            key: object.key
          })
          puts "  🗑️  Deleted: #{object.key}"
        end
        
        puts "✅ Cleanup complete"
      else
        puts "No Inkra voice files found to clean up"
      end
      
    rescue => e
      puts "❌ Failed to cleanup: #{e.message}"
    end
  end
end