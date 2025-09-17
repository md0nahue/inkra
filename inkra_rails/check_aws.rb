#!/usr/bin/env ruby

require 'dotenv/load'
require 'aws-sdk-s3'

puts "\n🔍 Checking AWS Configuration...\n"

# Check environment variables
puts "📋 Environment Variables:"
puts "   AWS_ACCESS_KEY_ID: #{ENV['AWS_ACCESS_KEY_ID'] ? '✅ Set' : '❌ Missing'}"
puts "   AWS_SECRET_ACCESS_KEY: #{ENV['AWS_SECRET_ACCESS_KEY'] ? '✅ Set' : '❌ Missing'}"
puts "   AWS_REGION: #{ENV['AWS_REGION'] || 'us-east-1'}"
puts "   AWS_S3_BUCKET: #{ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'}"

if !ENV['AWS_ACCESS_KEY_ID'] || !ENV['AWS_SECRET_ACCESS_KEY']
  puts "\n❌ AWS credentials not found in environment!"
  puts "Please update /Users/magnusfremont/Desktop/VibeWriter/vibewrite_rails/.env with your AWS credentials"
  exit 1
end

# Test AWS connection
begin
  puts "\n🔗 Testing AWS S3 connection..."
  
  s3_client = Aws::S3::Client.new(
    region: ENV['AWS_REGION'] || 'us-east-1',
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  )
  
  # List buckets to test credentials
  buckets = s3_client.list_buckets
  puts "✅ AWS credentials are valid!"
  puts "📦 Found #{buckets.buckets.count} bucket(s):"
  buckets.buckets.each do |bucket|
    puts "   - #{bucket.name}"
  end
  
  # Check if our bucket exists
  bucket_name = ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'
  begin
    s3_client.head_bucket(bucket: bucket_name)
    puts "\n✅ Bucket '#{bucket_name}' exists and is accessible!"
  rescue Aws::S3::Errors::NotFound
    puts "\n⚠️  Bucket '#{bucket_name}' does not exist. Creating it..."
    begin
      s3_client.create_bucket(bucket: bucket_name)
      puts "✅ Bucket created successfully!"
    rescue => e
      puts "❌ Failed to create bucket: #{e.message}"
    end
  rescue => e
    puts "\n❌ Cannot access bucket '#{bucket_name}': #{e.message}"
  end
  
  # Test creating a presigned URL
  puts "\n🔑 Testing presigned URL generation..."
  presigner = Aws::S3::Presigner.new(client: s3_client)
  test_url = presigner.presigned_url(
    :put_object,
    bucket: bucket_name,
    key: "test/test_file.m4a",
    expires_in: 3600,
    content_type: "audio/m4a"
  )
  
  puts "✅ Successfully generated presigned URL!"
  puts "🔗 Sample URL: #{test_url[0..100]}..."
  
rescue Aws::Errors::MissingCredentialsError => e
  puts "\n❌ AWS credentials error: #{e.message}"
  puts "Make sure your .env file contains valid AWS credentials"
rescue => e
  puts "\n❌ AWS error: #{e.class} - #{e.message}"
  puts "Please check your AWS credentials and permissions"
end

# Check Rails credentials
puts "\n📋 Checking Rails credentials..."
require_relative 'config/environment'

if Rails.application.credentials.aws
  puts "✅ AWS credentials found in Rails credentials"
  puts "   Region: #{Rails.application.credentials.dig(:aws, :region) || 'Not set'}"
  puts "   Bucket: #{Rails.application.credentials.dig(:aws, :s3_bucket) || 'Not set'}"
else
  puts "ℹ️  No AWS credentials in Rails credentials (using .env instead)"
end