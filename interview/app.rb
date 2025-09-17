require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'

# Load interview questions from YAML
INTERVIEWS = YAML.load_file('interview_questions.yaml')

# Helper methods
helpers do
  def format_question_number(index)
    index + 1
  end
  
  def truncate_text(text, length = 100)
    return text if text.length <= length
    text[0...length] + '...'
  end
end

# Routes
get '/' do
  @interviews = INTERVIEWS['interviews']
  erb :index
end

get '/book/:book_id' do
  book_id = params[:book_id].to_i
  @book = INTERVIEWS['interviews'][book_id]
  halt 404 unless @book
  @book_id = book_id
  erb :book
end

get '/book/:book_id/track/:track_id' do
  book_id = params[:book_id].to_i
  track_id = params[:track_id].to_i
  
  @book = INTERVIEWS['interviews'][book_id]
  halt 404 unless @book
  
  @track = @book['tracks'][track_id]
  halt 404 unless @track
  
  @book_id = book_id
  @track_id = track_id
  @total_tracks = @book['tracks'].length
  
  erb :track
end

# 404 handler
not_found do
  erb :not_found
end