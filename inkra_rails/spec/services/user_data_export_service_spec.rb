require 'rails_helper'

RSpec.describe UserDataExportService do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:audio_segment) { create(:audio_segment, project: project) }
  let(:service) { described_class.new(user) }

  describe '#generate_csv_files' do
    it 'generates CSV files for user data' do
      # Create test data
      project
      audio_segment

      temp_dir = Rails.root.join('tmp', 'test_export')
      FileUtils.mkdir_p(temp_dir)
      FileUtils.mkdir_p(temp_dir.join('data'))

      begin
        csv_files = service.send(:generate_csv_files, temp_dir)

        expect(csv_files).to be_a(Hash)
        expect(csv_files.keys).to include(
          'users.csv',
          'projects.csv',
          'questions.csv',
          'audio_segments.csv',
          'transcripts.csv',
          'feedbacks.csv',
          'device_logs.csv',
          'advisor_interactions.csv'
        )

        # Verify files were created
        csv_files.each do |filename, filepath|
          expect(File.exist?(filepath)).to be true
          expect(File.size(filepath)).to be > 0
        end

        # Verify users.csv content
        users_csv = CSV.read(csv_files['users.csv'], headers: true)
        expect(users_csv.length).to eq(1)
        expect(users_csv.first['email']).to eq(user.email)

        # Verify projects.csv content
        projects_csv = CSV.read(csv_files['projects.csv'], headers: true)
        expect(projects_csv.length).to eq(1)
        expect(projects_csv.first['title']).to eq(project.title)

      ensure
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end
  end

  describe '#create_complete_export' do
    it 'creates a complete export zip file' do
      # Mock S3 download to avoid external dependencies
      allow(service).to receive(:download_s3_file).and_return(true)

      zip_path = nil
      begin
        zip_path = service.create_complete_export

        expect(zip_path).to be_present
        expect(File.exist?(zip_path)).to be true
        expect(File.extname(zip_path)).to eq('.zip')

        # Verify zip contents
        zip_contents = []
        Zip::File.open(zip_path) do |zip_file|
          zip_file.each do |entry|
            zip_contents << entry.name
          end
        end

        expect(zip_contents).to include('README.txt')
        expect(zip_contents).to include('data/users.csv')
        expect(zip_contents).to include('data/projects.csv')
        expect(zip_contents).to include('data/audio_segments.csv')

      ensure
        File.delete(zip_path) if zip_path && File.exist?(zip_path)
      end
    end
  end
end