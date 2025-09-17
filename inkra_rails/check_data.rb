#!/usr/bin/env ruby

# Load the Rails environment
require File.expand_path('../config/environment', __FILE__)

puts "=== Database Check ==="
puts "Total LogEntry count: #{LogEntry.count}"
puts "Total Tracker count: #{Tracker.count}"

# Check for orphaned entries
orphaned_count = LogEntry.where(tracker_id: nil).count
puts "LogEntries with nil tracker_id: #{orphaned_count}"

# Check for entries with missing tracker associations
if LogEntry.count > 0
  entries_with_trackers = LogEntry.joins(:tracker).count
  puts "LogEntries that successfully join with tracker: #{entries_with_trackers}"
  puts "Potential orphaned entries: #{LogEntry.count - entries_with_trackers}"
  
  # Show a sample entry
  first_entry = LogEntry.includes(:tracker).first
  if first_entry
    puts "\nFirst LogEntry details:"
    puts "  ID: #{first_entry.id}"
    puts "  tracker_id: #{first_entry.tracker_id}"
    puts "  tracker present: #{first_entry.tracker.present?}"
    puts "  tracker name: #{first_entry.tracker&.name || 'N/A'}"
  end
end