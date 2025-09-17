namespace :voice_demos do
  desc "Generate demo audio files for all curated voices and upload to S3"
  task generate: :environment do
    puts "Generating voice demos..."
    
    results = VoiceDemoGenerator.generate_all_demos
    
    results.each_with_index do |url, index|
      voice = VoiceDemoGenerator::CURATED_VOICES[index]
      if url
        puts "✓ Generated demo for #{voice[:id]}: #{url}"
      else
        puts "✗ Failed to generate demo for #{voice[:id]}"
      end
    end
    
    puts "Voice demo generation complete!"
  end
  
  desc "List all voice demo URLs"
  task list: :environment do
    puts "Voice demo URLs:"
    VoiceDemoGenerator.get_all_voice_urls.each do |voice|
      puts "#{voice[:voice_id]} (#{voice[:engine]}): #{voice[:demo_url]}"
    end
  end
end