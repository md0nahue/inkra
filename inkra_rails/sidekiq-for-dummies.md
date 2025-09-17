# Sidekiq for Dummies (Coming from DelayedJob)

## Background: DelayedJob vs Sidekiq

**DelayedJob:**
- Jobs stored in PostgreSQL `delayed_jobs` table
- Query jobs with SQL: `SELECT * FROM delayed_jobs WHERE failed_at IS NULL`
- Single-threaded by default
- Easy to debug with SQL queries

**Sidekiq:**
- Jobs stored in Redis (not PostgreSQL!)
- Query jobs with Redis commands or Web UI
- Multi-threaded (5 threads by default)
- Better performance, different debugging approach

## Starting Sidekiq

```bash
# In your Rails app directory
bundle exec sidekiq

# With custom config
bundle exec sidekiq -C config/sidekiq.yml

# With specific queues
bundle exec sidekiq -q critical,2 -q default,1

# In background (production)
bundle exec sidekiq -d -L log/sidekiq.log
```

## Sidekiq Web UI (Your New Best Friend)

Add to your `config/routes.rb`:
```ruby
require 'sidekiq/web'

Rails.application.routes.draw do
  # Mount Sidekiq web UI (protect in production!)
  if Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
  end
  
  # Your other routes...
end
```

Then visit: **http://localhost:3000/sidekiq**

### What you'll see in the Web UI:
- **Dashboard**: Job counts, queues, workers
- **Queues**: Pending jobs (like your DelayedJob backlog)
- **Busy**: Currently running jobs
- **Dead**: Failed jobs that won't retry
- **Retries**: Failed jobs that will retry
- **Scheduled**: Future jobs
- **Cron**: Recurring jobs (if using sidekiq-cron)

## Command Line Inspection (Like Your SQL Queries)

### Using Rails Console

```ruby
# Start Rails console
rails console

# Check job counts (like COUNT(*) from delayed_jobs)
require 'sidekiq/api'

# Pending jobs in default queue
Sidekiq::Queue.new.size
# => 5

# All queues
Sidekiq::Stats.new.queues
# => {"default"=>5, "critical"=>2, "mailers"=>0}

# Failed jobs count
Sidekiq::RetrySet.new.size
# => 3

# Dead jobs count  
Sidekiq::DeadSet.new.size
# => 1

# Processing jobs (currently running)
Sidekiq::ProcessSet.new.size
# => 2
```

### Inspect Specific Jobs

```ruby
# Get jobs in default queue (like SELECT * FROM delayed_jobs)
queue = Sidekiq::Queue.new("default")
queue.each do |job|
  puts "Job: #{job.klass}"
  puts "Args: #{job.args}"
  puts "Created: #{job.created_at}"
  puts "Queue: #{job.queue}"
  puts "---"
end

# Get failed jobs (like WHERE failed_at IS NOT NULL)
Sidekiq::RetrySet.new.each do |job|
  puts "Failed: #{job.klass}"
  puts "Error: #{job.error_message}"
  puts "Failed at: #{job.failed_at}"
  puts "Retry count: #{job.retry_count}"
  puts "---"
end

# Get dead jobs (like WHERE attempts >= max_attempts)
Sidekiq::DeadSet.new.each do |job|
  puts "Dead: #{job.klass}" 
  puts "Error: #{job.error_message}"
  puts "Died at: #{job.dead_at}"
  puts "---"
end
```

### Job Management (Like DELETE FROM delayed_jobs)

```ruby
# Clear all jobs in a queue
Sidekiq::Queue.new("default").clear

# Clear all failed jobs
Sidekiq::RetrySet.new.clear

# Clear all dead jobs
Sidekiq::DeadSet.new.clear

# Delete specific job
queue = Sidekiq::Queue.new("default")
queue.each do |job|
  if job.args.first == "some_condition"
    job.delete
  end
end

# Retry all failed jobs
Sidekiq::RetrySet.new.retry_all

# Kill/move to dead queue
retry_set = Sidekiq::RetrySet.new
retry_set.each do |job|
  if job.retry_count > 5
    job.kill  # Move to dead queue
  end
end
```

## Common Commands You'll Use

### Check Job Status
```ruby
# How many jobs are waiting? (like your DelayedJob backlog)
Sidekiq::Stats.new.enqueued
# => 23

# How many jobs failed today?
Sidekiq::Stats.new.failed  
# => 5

# How many jobs processed today?
Sidekiq::Stats.new.processed
# => 1247
```

### Find Specific Jobs
```ruby
# Find TranscriptionJob jobs
Sidekiq::Queue.new.select { |job| job.klass == "TranscriptionJob" }

# Find jobs for specific audio segment
Sidekiq::Queue.new.select do |job| 
  job.klass == "TranscriptionJob" && job.args.first == 22  # audio_segment_id
end

# Find jobs older than 1 hour
Sidekiq::Queue.new.select { |job| job.created_at < 1.hour.ago }
```

### Debugging Failed Jobs
```ruby
# Get last failed job details
failed_job = Sidekiq::RetrySet.new.first
puts failed_job.error_message
puts failed_job.error_backtrace
puts failed_job.args

# Retry specific failed job
failed_job.retry

# Or delete it
failed_job.delete
```

## Redis CLI (Advanced)

If you want to go deeper (like raw SQL), use Redis CLI:

```bash
# Connect to Redis
redis-cli

# List all Sidekiq keys
KEYS *sidekiq*

# Get queue size
LLEN queue:default

# See job details
LINDEX queue:default 0

# See all stats
HGETALL stat:processed
```

## Monitoring Production

### Sidekiq Process Status
```bash
# Check if Sidekiq is running
ps aux | grep sidekiq

# Kill Sidekiq gracefully
kill -TERM <sidekiq_pid>

# Kill Sidekiq immediately  
kill -9 <sidekiq_pid>
```

### Log Files
```bash
# Default Sidekiq logs to STDOUT, but you can redirect:
bundle exec sidekiq > log/sidekiq.log 2>&1

# Or use built-in logging:
bundle exec sidekiq -L log/sidekiq.log
```

## Your Inkra App Specific Commands

```ruby
# Check transcription job queue
Sidekiq::Queue.new.select { |job| job.klass == "TranscriptionJob" }.size

# Find failed transcriptions
Sidekiq::RetrySet.new.select { |job| job.klass == "TranscriptionJob" }

# Check specific audio segment transcription
audio_segment_id = 22
Sidekiq::Queue.new.find { |job| 
  job.klass == "TranscriptionJob" && job.args.first == audio_segment_id 
}

# Retry failed transcription jobs only
Sidekiq::RetrySet.new.each do |job|
  if job.klass == "TranscriptionJob"
    job.retry
  end
end

# Clear all follow-up question jobs
Sidekiq::Queue.new.each do |job|
  if job.klass == "GenerateFollowupQuestionsJob"
    job.delete  
  end
end
```

## Quick Reference Card

| DelayedJob (SQL) | Sidekiq (Redis) | What it does |
|------------------|-----------------|--------------|
| `SELECT COUNT(*) FROM delayed_jobs WHERE failed_at IS NULL` | `Sidekiq::Stats.new.enqueued` | Count pending jobs |
| `SELECT * FROM delayed_jobs WHERE failed_at IS NOT NULL` | `Sidekiq::RetrySet.new` | Get failed jobs |
| `DELETE FROM delayed_jobs WHERE id = 123` | `job.delete` | Delete specific job |
| `UPDATE delayed_jobs SET failed_at = NULL WHERE id = 123` | `job.retry` | Retry specific job |
| `SELECT * FROM delayed_jobs ORDER BY created_at` | `Sidekiq::Queue.new.each` | List all jobs |

## Pro Tips

1. **Always use the Web UI first** - it's much easier than console commands
2. **Check Redis memory** - jobs are stored in RAM, not disk
3. **Failed != Dead** - failed jobs will retry, dead jobs won't
4. **Threads matter** - 5 concurrent jobs by default (vs DelayedJob's 1)
5. **Queues are just Redis lists** - you can prioritize them
6. **No database bloat** - Redis auto-expires completed jobs

## Emergency Commands

```ruby
# PANIC: Clear everything and start fresh
Sidekiq::Queue.new.clear
Sidekiq::RetrySet.new.clear  
Sidekiq::DeadSet.new.clear

# PANIC: Stop all processing
Sidekiq::ProcessSet.new.each(&:stop!)

# Check if workers are alive
Sidekiq::ProcessSet.new.each { |p| puts "#{p.hostname}: #{p.busy} busy, #{p.threads} threads" }
```