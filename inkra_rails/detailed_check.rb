#!/usr/bin/env ruby

# Load the Rails environment
require File.expand_path('../config/environment', __FILE__)

puts "=== Detailed Database Check ==="

# Check all trackers
puts "All Trackers:"
Tracker.all.each do |tracker|
  puts "  ID: #{tracker.id}, Name: #{tracker.name}"
end

# Check all log entries
puts "\nAll LogEntries:"
LogEntry.includes(:tracker).each do |entry|
  puts "  ID: #{entry.id}, tracker_id: #{entry.tracker_id}, status: #{entry.status}"
  puts "    tracker present: #{entry.tracker.present?}"
  if entry.tracker
    puts "    tracker name: #{entry.tracker.name}"
  else
    puts "    ERROR: tracker is nil but tracker_id is #{entry.tracker_id}"
  end
end

# Test the serialization
puts "\n=== Testing Serialization ==="
entry = LogEntry.includes(:tracker).first
if entry
  puts "Testing serialize_entry logic..."
  
  # Simulate the serialize_entry method logic
  puts "Entry ID: #{entry.id}"
  puts "Entry tracker_id: #{entry.tracker_id}"
  puts "Entry tracker present: #{entry.tracker.present?}"
  
  if entry.tracker_id.nil?
    puts "ERROR: tracker_id is nil!"
  else
    puts "tracker_id is present: #{entry.tracker_id}"
  end
  
  if entry.tracker.nil?
    puts "ERROR: tracker association is nil!"
  else
    puts "tracker association is present"
    puts "  name: #{entry.tracker.name}"
    puts "  sf_symbol_name: #{entry.tracker.sf_symbol_name}"
    puts "  color_hex: #{entry.tracker.color_hex}"
  end
  
  # Manually build the hash to see what would be serialized
  serialized = {
    id: entry.id,
    tracker_id: entry.tracker_id,
    tracker_name: entry.tracker&.name || "Unknown Tracker",
    tracker_symbol: entry.tracker&.sf_symbol_name || "questionmark.circle",
    tracker_color: entry.tracker&.color_hex || "#FF0000",
    timestamp_utc: entry.timestamp_utc,
    transcription_text: entry.transcription_text,
    notes: entry.notes,
    audio_file_url: entry.audio_file_url,
    duration_seconds: entry.duration_seconds,
    status: entry.status
  }
  
  puts "\nSerialized hash:"
  puts serialized.inspect
  puts "\nAs JSON:"
  puts serialized.to_json
end