#!/usr/bin/env ruby

# Clean up Sidekiq job queue before starting development
require_relative 'config/environment'
require 'sidekiq/api'

puts "\n🔍 Examining Sidekiq Job Queue (Redis Backend)"
puts "=" * 50

# Check Redis connection
begin
  redis_info = Sidekiq.redis { |conn| conn.info }
  puts "✅ Redis connected: #{redis_info['redis_version']}"
rescue => e
  puts "❌ Redis not available: #{e.message}"
  puts "Start Redis with: brew services start redis"
  exit 1
end

# Show current job counts
stats = Sidekiq::Stats.new
puts "\n📊 Current Job Counts:"
puts "  Enqueued (waiting): #{stats.enqueued}"
puts "  Failed (will retry): #{stats.retry_size}" 
puts "  Dead (won't retry): #{stats.dead_size}"
puts "  Processed (total): #{stats.processed}"
puts "  Failed (total): #{stats.failed}"

# Show queues
puts "\n📋 Queue Details:"
stats.queues.each do |name, size|
  puts "  #{name}: #{size} jobs"
end

# Examine pending jobs
puts "\n📝 Pending Jobs:"
if stats.enqueued == 0
  puts "  No pending jobs"
else
  Sidekiq::Queue.new.each_with_index do |job, i|
    puts "  #{i + 1}. #{job.klass} - Args: #{job.args} - Created: #{job.created_at}"
  end
end

# Examine failed jobs
puts "\n❌ Failed Jobs:"
if stats.retry_size == 0
  puts "  No failed jobs"
else
  Sidekiq::RetrySet.new.each_with_index do |job, i|
    puts "  #{i + 1}. #{job.klass} - Error: #{job.error_message[0..100]}... - Failed: #{job.failed_at}"
  end
end

# Examine dead jobs
puts "\n💀 Dead Jobs:"
if stats.dead_size == 0
  puts "  No dead jobs"
else
  Sidekiq::DeadSet.new.each_with_index do |job, i|
    puts "  #{i + 1}. #{job.klass} - Error: #{job.error_message[0..100]}... - Died: #{job.dead_at}"
  end
end

# Interactive cleanup
puts "\n🧹 Cleanup Options:"
puts "1. Clear all pending jobs"
puts "2. Clear all failed jobs" 
puts "3. Clear all dead jobs"
puts "4. Clear EVERYTHING (fresh start)"
puts "5. Keep everything (no changes)"
puts "6. Show detailed job info"

print "\nChoice (1-6): "
choice = gets.chomp

case choice
when "1"
  count = Sidekiq::Queue.new.clear
  puts "✅ Cleared #{count} pending jobs"
  
when "2"
  count = Sidekiq::RetrySet.new.clear
  puts "✅ Cleared #{count} failed jobs"
  
when "3"
  count = Sidekiq::DeadSet.new.clear 
  puts "✅ Cleared #{count} dead jobs"
  
when "4"
  pending = Sidekiq::Queue.new.clear
  failed = Sidekiq::RetrySet.new.clear
  dead = Sidekiq::DeadSet.new.clear
  puts "✅ CLEARED EVERYTHING:"
  puts "  - #{pending} pending jobs"
  puts "  - #{failed} failed jobs" 
  puts "  - #{dead} dead jobs"
  
when "5"
  puts "✅ No changes made"
  
when "6"
  puts "\n🔍 Detailed Job Information:"
  
  if stats.enqueued > 0
    puts "\n📝 Pending Jobs Details:"
    Sidekiq::Queue.new.each_with_index do |job, i|
      puts "  Job #{i + 1}:"
      puts "    Class: #{job.klass}"
      puts "    Queue: #{job.queue}"
      puts "    Args: #{job.args.inspect}"
      puts "    Created: #{job.created_at}"
      puts "    JID: #{job.jid}"
      puts ""
    end
  end
  
  if stats.retry_size > 0
    puts "\n❌ Failed Jobs Details:"
    Sidekiq::RetrySet.new.each_with_index do |job, i|
      puts "  Failed Job #{i + 1}:"
      puts "    Class: #{job.klass}"
      puts "    Args: #{job.args.inspect}"
      puts "    Error: #{job.error_message}"
      puts "    Failed at: #{job.failed_at}"
      puts "    Retry count: #{job.retry_count}"
      puts "    Next retry: #{job.at}"
      puts ""
    end
  end
  
else
  puts "Invalid choice, no changes made"
end

# Show final status
final_stats = Sidekiq::Stats.new
puts "\n📊 Final Status:"
puts "  Enqueued: #{final_stats.enqueued}"
puts "  Failed: #{final_stats.retry_size}"
puts "  Dead: #{final_stats.dead_size}"

puts "\n🚀 Ready to start Sidekiq with: bundle exec sidekiq"
puts "💻 Or view web UI at: http://localhost:3000/sidekiq (after starting Rails)"