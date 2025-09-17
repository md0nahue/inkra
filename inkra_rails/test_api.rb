#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Test the vibelog entries endpoint
uri = URI('http://localhost:3000/api/vibelog/entries')
uri.query = URI.encode_www_form({
  page: 1
})

puts "Testing endpoint: #{uri}"

http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Get.new(uri)

# You'll need a valid JWT token here - this is just to test the structure
# request['Authorization'] = 'Bearer YOUR_TOKEN_HERE'

begin
  response = http.request(request)
  puts "Status: #{response.code}"
  puts "Headers: #{response.to_hash}"
  puts "Body: #{response.body}"
  
  if response.body && !response.body.empty?
    begin
      parsed = JSON.parse(response.body)
      puts "\nParsed JSON:"
      puts JSON.pretty_generate(parsed)
      
      if parsed['entries'] && parsed['entries'].any?
        puts "\nFirst entry keys:"
        puts parsed['entries'].first.keys.sort
      end
    rescue JSON::ParserError => e
      puts "Failed to parse JSON: #{e.message}"
    end
  end
rescue => e
  puts "Request failed: #{e.message}"
end