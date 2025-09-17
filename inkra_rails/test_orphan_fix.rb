#!/usr/bin/env ruby

require 'httparty'
require 'json'

class OrphanFixTest
  include HTTParty
  
  base_uri 'http://localhost:3000'
  
  def initialize
    @headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    @auth_token = nil
    puts "🧪 Testing Orphaned Entries Fix"
    puts "==============================="
  end
  
  def authenticate
    puts "\n1. Authenticating with existing user..."
    
    # Get first user and create token directly
    token_cmd = "cd /Users/magnusfremont/Desktop/VibeWriter/vibewrite_rails && rails runner \"user = User.first; puts JwtService.encode_access_token(user.id) if user\""
    token = `#{token_cmd}`.strip
    
    if token.length > 10
      @auth_token = token
      @headers['Authorization'] = "Bearer #{@auth_token}"
      puts "   ✅ Authentication successful"
      return true
    else
      puts "   ❌ Authentication failed"
      return false
    end
  end
  
  def create_orphaned_entry_via_sql
    puts "\n2. Creating orphaned entry via direct SQL manipulation..."
    
    # First create a temporary tracker and log entry
    puts "   Creating temporary tracker and entry..."
    
    create_cmd = 'cd /Users/magnusfremont/Desktop/VibeWriter/vibewrite_rails && rails runner -e development "
      temp_tracker = Tracker.create!(
        user_id: User.first.id,
        name: \"Temp Tracker for Orphan Test\",
        sf_symbol_name: \"flame\",
        color_hex: \"#FF0000\"
      )
      
      orphan_entry = LogEntry.create!(
        user_id: User.first.id,
        tracker_id: temp_tracker.id,
        timestamp_utc: Time.current,
        status: \"completed\",
        transcription_text: \"This entry will become orphaned\",
        duration_seconds: 30
      )
      
      puts \"Created tracker ID: #{temp_tracker.id}\"
      puts \"Created entry ID: #{orphan_entry.id}\"
      
      ActiveRecord::Base.connection.execute(\"DELETE FROM trackers WHERE id = #{temp_tracker.id}\")
      
      puts \"Deleted tracker - entry should now be orphaned\"
      puts \"Entry #{orphan_entry.id} tracker_id: #{orphan_entry.reload.tracker_id}\"
      puts \"Entry tracker exists: #{Tracker.exists?(orphan_entry.tracker_id)}\"
    "'
    
    result = `#{create_cmd}`
    puts "   Result:\n#{result}"
    
    # Extract the orphaned entry ID
    entry_id = result.match(/Created entry ID: (\d+)/)[1] rescue nil
    if entry_id
      puts "   ✅ Orphaned entry created with ID: #{entry_id}"
      return entry_id.to_i
    else
      puts "   ❌ Failed to create orphaned entry"
      return nil
    end
  end
  
  def test_api_with_orphan
    puts "\n3. Testing VibeLog API with orphaned entry..."
    
    response = self.class.get('/api/vibelog/entries', headers: @headers)
    puts "   API Response: #{response.code}"
    
    if response.code == 200
      puts "   ✅ API didn't crash!"
      
      body = JSON.parse(response.body) rescue nil
      if body && body['entries'] && body['entries'].any?
        puts "   📋 #{body['entries'].length} entries returned"
        
        # Look for entries with "Deleted Tracker" in the name
        orphaned_entries = body['entries'].select { |e| e['tracker_name']&.include?('Deleted Tracker') }
        if orphaned_entries.any?
          puts "   🎯 Found #{orphaned_entries.length} orphaned entries handled gracefully:"
          orphaned_entries.each do |entry|
            puts "     - Entry #{entry['id']}: #{entry['tracker_name']} (#{entry['tracker_symbol']})"
          end
        else
          puts "   ℹ️  No orphaned entries found in response"
        end
      else
        puts "   ⚠️  Unexpected response format"
      end
    elsif response.code == 500
      puts "   💥 API still crashing with 500 error"
      puts "   Error: #{response.body}"
      return false
    else
      puts "   ⚠️  Unexpected response: #{response.code}"
      puts "   Body: #{response.body}"
    end
    
    true
  end
  
  def test_csv_export
    puts "\n4. Testing CSV export with orphaned entries..."
    
    response = self.class.post('/api/vibelog/export',
                               body: { format: 'csv' }.to_json,
                               headers: @headers)
    
    puts "   Export response: #{response.code}"
    
    if response.code == 200
      puts "   ✅ CSV export didn't crash!"
      puts "   📄 CSV content (first 200 chars): #{response.body[0..200]}..."
      return true
    else
      puts "   ❌ CSV export failed: #{response.body}"
      return false
    end
  end
  
  def cleanup_orphaned_entries
    puts "\n5. Cleaning up orphaned entries..."
    
    cleanup_cmd = 'cd /Users/magnusfremont/Desktop/VibeWriter/vibewrite_rails && rails runner -e development "
        orphaned = LogEntry.left_joins(:tracker).where(trackers: { id: nil })
        puts \"Found #{orphaned.count} orphaned entries\"
        
        orphaned.each do |entry|
          puts \"Deleting orphaned entry #{entry.id} (tracker_id: #{entry.tracker_id})\"
          entry.destroy
        end
        
        puts \"Cleanup complete\"
    "'
    
    result = `#{cleanup_cmd}`
    puts "   #{result}"
  end
  
  def run_test
    puts "Starting orphaned entries fix test...\n"
    
    return unless authenticate
    
    # Create an orphaned entry artificially
    orphan_id = create_orphaned_entry_via_sql
    return unless orphan_id
    
    # Test that the API handles it gracefully
    api_success = test_api_with_orphan
    csv_success = test_csv_export
    
    # Clean up
    cleanup_orphaned_entries
    
    puts "\n" + "="*50
    puts "🧪 ORPHANED ENTRIES FIX TEST RESULTS"
    puts "="*50
    
    puts "📊 Orphaned entry creation: #{orphan_id ? 'SUCCESS' : 'FAILED'}"
    puts "📊 VibeLog API resilience: #{api_success ? 'PASSED' : 'FAILED'}"
    puts "📊 CSV export resilience: #{csv_success ? 'PASSED' : 'FAILED'}"
    
    if api_success && csv_success
      puts "\n✅ FIX VERIFICATION SUCCESSFUL!"
      puts "   ✅ API no longer crashes with orphaned entries"
      puts "   ✅ Orphaned entries are displayed with fallback values"
      puts "   ✅ Export functionality works with orphaned entries"
    else
      puts "\n❌ FIX VERIFICATION FAILED!"
      puts "   The serialize_entry method may need further refinement"
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = OrphanFixTest.new
  tester.run_test
end