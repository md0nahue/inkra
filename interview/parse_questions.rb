#!/usr/bin/env ruby
require 'yaml'

def parse_interview_questions(file_path)
  content = File.read(file_path)
  lines = content.lines
  
  interviews = []
  current_track = nil
  current_description = nil
  current_questions = []
  question_buffer = []
  
  lines.each_with_index do |line, idx|
    line = line.strip
    
    # Skip empty lines
    next if line.empty? || line == '-' * 80
    
    # Check for interview track header
    if line.match(/^Interview Track (\d+): (.+)$/)
      # Save previous track if exists
      if current_track
        interviews << {
          'track_number' => current_track[:number],
          'title' => current_track[:title],
          'description' => current_description || '',
          'questions' => current_questions
        }
      end
      
      # Start new track
      current_track = { number: $1.to_i, title: $2 }
      current_description = nil
      current_questions = []
      question_buffer = []
      
    # Check for description (line after track header)
    elsif current_track && current_description.nil? && !line.match(/^\d+\./)
      current_description = line
      
    # Check for question start
    elsif line.match(/^(\d+)\.\s+(.+)$/)
      # Save previous question if exists
      if !question_buffer.empty?
        current_questions << question_buffer.join(' ')
        question_buffer = []
      end
      
      # Start new question
      question_buffer = [$2]
      
    # Continue multi-line question
    elsif !question_buffer.empty? && !line.match(/^Interview Track/)
      question_buffer << line
    end
  end
  
  # Save last question
  if !question_buffer.empty?
    current_questions << question_buffer.join(' ')
  end
  
  # Save last track
  if current_track
    interviews << {
      'track_number' => current_track[:number],
      'title' => current_track[:title],
      'description' => current_description || '',
      'questions' => current_questions
    }
  end
  
  # Group interviews by source/book
  grouped_interviews = {
    'interviews' => []
  }
  
  # Detect different book sections based on patterns
  book_sections = []
  current_book = nil
  
  interviews.each_with_index do |track, idx|
    # Check if this is the start of a new book section (track 1 after several tracks)
    if track['track_number'] == 1 && idx > 0
      if current_book
        book_sections << current_book
      end
      current_book = {
        'source' => "Book #{book_sections.length + 1}",
        'tracks' => []
      }
    elsif current_book.nil?
      current_book = {
        'source' => "Book 1",
        'tracks' => []
      }
    end
    
    current_book['tracks'] << track
  end
  
  # Add last book section
  if current_book
    book_sections << current_book
  end
  
  # Update source names based on content patterns
  book_sections.each_with_index do |book, idx|
    case idx
    when 0
      book['source'] = 'The Courage to Be Disliked & Think Like a Monk'
    when 1
      book['source'] = "The Artist's Way & Essentialism"
    when 2
      book['source'] = 'Declutter Your Mind & Notes from a Friend'
    else
      book['source'] = "Additional Wisdom Collection #{idx - 2}"
    end
  end
  
  grouped_interviews['interviews'] = book_sections
  grouped_interviews
end

# Parse the questions file
questions_data = parse_interview_questions('questions.txt')

# Save to YAML
File.write('interview_questions.yaml', questions_data.to_yaml)

puts "Successfully parsed #{questions_data['interviews'].sum { |b| b['tracks'].length }} interview tracks"
puts "Saved to interview_questions.yaml"