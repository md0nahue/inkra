namespace :preset_questions do
  desc "Import all preset questions from YAML files"
  task import: :environment do
    puts "Starting preset questions import..."
    result = PresetQuestionsImporter.import_all
    
    puts "\nImport Summary:"
    puts "  Imported: #{result[:imported]} new presets"
    puts "  Updated: #{result[:updated]} existing presets"
    
    if result[:errors].any?
      puts "\nErrors encountered:"
      result[:errors].each { |error| puts "  - #{error}" }
    else
      puts "\nImport completed successfully!"
    end
  end

  desc "Clear all existing preset data and reimport"
  task reimport: :environment do
    puts "Clearing existing preset data..."
    InterviewPreset.destroy_all
    Rake::Task['preset_questions:import'].invoke
  end

  desc "Check sync status of YAML files vs database"
  task check_sync: :environment do
    yaml_dir = Rails.root.join('db', 'preset_questions')
    yaml_files = Dir.glob(File.join(yaml_dir, '*.yaml'))
    db_presets = InterviewPreset.count

    puts "YAML files: #{yaml_files.count}"
    puts "Database presets: #{db_presets}"
    
    if yaml_files.count == db_presets
      puts "✅ Files and database are in sync"
    else
      puts "❌ Files and database are out of sync"
      puts "   Run 'rails preset_questions:import' to sync"
    end
  end
end