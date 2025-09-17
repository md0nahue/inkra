require 'net/http'
require 'json'
require 'securerandom'
require 'digest'

class GeminiContentAnalysisService
  GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    @model = 'gemini-2.5-flash-lite'
    @max_tokens = 2048
    @temperature = 0.1
    
    raise "GEMINI_API_KEY environment variable not set" unless @api_key
  end

  # Analyze transcribed segments and generate image queries for Ken Burns videos
  # @param segments [Array] Transcribed audio segments
  # @param options [Hash] Analysis options
  # @return [Array] Segments with image queries and timing
  def analyze_content_for_images(segments, options = {})
    Rails.logger.info "🧠 Analyzing content for image generation using Gemini..."
    
    # Check for cached analysis (respect force option)
    cache_file = get_cache_file_path(segments, options)
    if File.exist?(cache_file) && !options[:force]
      Rails.logger.info "    📁 Using cached content analysis from: #{cache_file}"
      cached_data = JSON.parse(File.read(cache_file), symbolize_names: true)
      return cached_data
    elsif options[:force]
      Rails.logger.info "    🔄 Force mode enabled - bypassing cache"
    end
    
    # Process segments in smaller batches to avoid API limits
    batch_size = 10  # Process 10 segments at a time
    all_results = []
    
    Rails.logger.info "  📝 Analyzing #{segments.length} segments in batches of #{batch_size}..."
    
    segments.each_slice(batch_size).with_index do |batch, batch_index|
      Rails.logger.info "    🔄 Processing batch #{batch_index + 1}/#{(segments.length.to_f / batch_size).ceil} (#{batch.length} segments)"
      
      begin
        # Build prompt for this batch
        prompt = build_batch_analysis_prompt(batch, options)
        
        # Make API request for this batch
        response = make_gemini_request(prompt)
        
        # Parse the response
        batch_results = parse_batch_analysis_response(response, batch)
        
        # Add to overall results
        all_results.concat(batch_results)
        
        # Add delay between batches to respect rate limits
        sleep(2) if batch_index < (segments.length.to_f / batch_size).ceil - 1
        
      rescue => e
        Rails.logger.error "    ❌ Error processing batch #{batch_index + 1}: #{e.message}"
        # Add segments with fallback queries instead of failing completely
        batch.each do |segment|
          all_results << segment.merge({
            image_queries: generate_fallback_queries(segment[:text] || segment['text'] || ''),
            has_images: true
          })
        end
      end
    end
    
    # Cache the analysis result
    Rails.logger.info "    💾 Caching content analysis to: #{cache_file}"
    File.write(cache_file, JSON.pretty_generate(all_results))
    
    Rails.logger.info "✅ Content analysis completed: #{all_results.length} segments processed"
    all_results
  end

  # Generate image queries for a specific text segment
  # @param text [String] Text to analyze
  # @param context [Hash] Additional context
  # @return [Array] Image queries
  def generate_image_queries_for_text(text, context = {})
    prompt = build_single_text_prompt(text, context)
    
    response = make_gemini_request(prompt)
    
    parsed = parse_analysis_response(response)
    parsed[:image_queries] || []
  end

  private

  # Generate cache file path for content analysis
  # @param segments [Array] Audio segments
  # @param options [Hash] Analysis options
  # @return [String] Cache file path
  def get_cache_file_path(segments, options)
    # Create a hash of the segments and options to generate a unique cache key
    content_hash = Digest::MD5.hexdigest(segments.to_json + options.to_json)
    cache_dir = Rails.root.join('tmp', 'cache', 'gemini_analysis')
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    File.join(cache_dir, "gemini_analysis_#{content_hash}.json")
  end

  # Build prompt for single text analysis
  # @param text [String] Text to analyze
  # @param context [Hash] Additional context
  # @return [String] Formatted prompt
  def build_single_text_prompt(text, context = {})
    context_type = context[:type] || "content"
    style = context[:style] || "realistic, high-quality"
    
    prompt = <<~PROMPT
      You are an expert at analyzing text and determining what images would best illustrate the content.

      CONTEXT: This is #{context_type} that needs visual accompaniment.

      TEXT: "#{text.strip}"

      TASK: Generate 2-3 specific image search queries that would create compelling visual accompaniment.

      REQUIREMENTS:
      - Generate queries that are specific and descriptive
      - Focus on visual elements mentioned or implied in the text
      - Each query should be 2-6 words maximum
      - Prioritize queries that would work well for Ken Burns effects

      RESPONSE FORMAT (JSON only):
      {
        "image_queries": [
          "specific visual query 1",
          "specific visual query 2"
        ],
        "visual_style": "#{style}"
      }

      Generate only the JSON response, no other text.
    PROMPT

    prompt
  end

  # Make request to Gemini API
  # @param prompt [String] The prompt to send
  # @return [Hash] API response
  def make_gemini_request(prompt)
    uri = URI("#{GEMINI_API_BASE}/models/#{@model}:generateContent?key=#{@api_key}")
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      contents: [
        {
          parts: [
            {
              text: prompt
            }
          ]
        }
      ],
      generationConfig: {
        temperature: @temperature,
        maxOutputTokens: @max_tokens,
        topP: 0.8,
        topK: 40
      }
    }.to_json
    
    response = make_request(request, uri)
    
    if response['error']
      raise "Gemini API Error: #{response['error']['message']}"
    end
    
    response
  end

  # Make HTTP request
  # @param request [Net::HTTP::Request] The request object
  # @param uri [URI] The URI object
  # @return [Hash] Parsed JSON response
  def make_request(request, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 30
    
    response = http.request(request)
    
    if response.code != '200'
      raise "HTTP Error: #{response.code} - #{response.message}"
    end
    
    JSON.parse(response.body)
  rescue => e
    raise "Request failed: #{e.message}"
  end

  # Parse analysis response from Gemini
  # @param response [Hash] Gemini API response
  # @return [Hash] Parsed analysis result
  def parse_analysis_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    
    return { image_queries: [], primary_theme: '', visual_style: '' } unless content
    
    begin
      # Try to parse as JSON
      parsed = JSON.parse(content.strip)
      
      # Validate structure
      {
        image_queries: parsed['image_queries'] || [],
        primary_theme: parsed['primary_theme'] || '',
        visual_style: parsed['visual_style'] || 'realistic, high-quality',
        duration_suggestion: parsed['duration_suggestion']
      }
    rescue JSON::ParserError
      # Fallback: try to extract queries from text
      {
        image_queries: extract_queries_from_text(content),
        primary_theme: 'extracted from content',
        visual_style: 'realistic, high-quality'
      }
    end
  end

  # Extract queries from text when JSON parsing fails
  # @param text [String] Response text
  # @return [Array] Extracted queries
  def extract_queries_from_text(text)
    # Simple fallback extraction
    lines = text.split("\n")
    queries = []
    
    lines.each do |line|
      line = line.strip
      next if line.empty?
      
      # Look for quoted strings or simple phrases
      if line.match(/^["'](.+?)["']$/) || line.match(/^[-*]\s*(.+)$/)
        query = $1.strip
        queries << query if query.length > 2 && query.length < 50
      elsif line.match(/^(\w+(?:\s+\w+){1,5})$/)
        queries << line
      end
    end
    
    queries.uniq.first(4) # Limit to 4 queries
  end

  # Generate fallback queries from text
  # @param text [String] Text to analyze
  # @return [Array] Generated queries
  def generate_fallback_queries(text)
    # Create imaginative, positive, and cheerful fallback queries
    # These are designed to be engaging and work well for Ken Burns effects
    
    # Positive, cheerful themes that work well for video
    cheerful_themes = [
      "sunny landscape",
      "happy people",
      "beautiful nature",
      "inspiring architecture",
      "vibrant colors",
      "peaceful scenes",
      "creative workspace",
      "adventure travel",
      "artistic expression",
      "community celebration",
      "serene landscapes",
      "dynamic city life",
      "natural beauty",
      "cultural diversity",
      "innovative technology",
      "sustainable living",
      "human connection",
      "artistic creativity",
      "urban exploration",
      "rural tranquility"
    ]
    
    # Extract some context from the text to make queries more relevant
    words = text.downcase.split(/\W+/).reject { |w| w.length < 3 }
    
    # Look for specific themes in the text
    if text.match(/tech|digital|computer|phone|device/i)
      queries = ["modern technology", "innovative design", "digital lifestyle"]
    elsif text.match(/business|work|professional|career/i)
      queries = ["professional workspace", "business collaboration", "modern office"]
    elsif text.match(/nature|outdoor|environment|green/i)
      queries = ["natural landscape", "environmental beauty", "outdoor adventure"]
    elsif text.match(/city|urban|building|architecture/i)
      queries = ["urban architecture", "city skyline", "modern cityscape"]
    elsif text.match(/people|human|person|community/i)
      queries = ["diverse community", "human connection", "cultural celebration"]
    elsif text.match(/art|creative|design|artistic/i)
      queries = ["artistic expression", "creative workspace", "design inspiration"]
    elsif text.match(/travel|adventure|exploration/i)
      queries = ["adventure travel", "exploration journey", "world discovery"]
    elsif text.match(/food|cooking|culinary/i)
      queries = ["culinary artistry", "food culture", "gourmet experience"]
    elsif text.match(/music|sound|audio/i)
      queries = ["musical expression", "sound studio", "creative performance"]
    elsif text.match(/health|wellness|fitness/i)
      queries = ["healthy lifestyle", "wellness journey", "active living"]
    else
      # Default to positive, engaging themes
      queries = cheerful_themes.sample(3)
    end
    
    # Ensure we have exactly 3 queries
    queries = queries.first(3)
    while queries.length < 3
      queries << cheerful_themes.sample
    end
    
    queries.uniq.first(3)
  end

  # Build a single comprehensive prompt for all segments
  # @param segments [Array] Transcribed audio segments
  # @param options [Hash] Analysis options
  # @return [String] Formatted prompt
  def build_batch_analysis_prompt(segments, options)
    context = options[:context] || "content analysis"
    style = options[:style] || "realistic, high-quality"
    
    # Calculate total duration
    total_duration = segments.sum { |s| (s[:end_time] || s['end'] || 0) - (s[:start_time] || s['start'] || 0) }
    
    prompt = <<~PROMPT
      You are an expert at analyzing spoken content and determining what images would best illustrate the narrative.

      CONTEXT: This is a #{context} that has been transcribed from audio.

      AUDIO SEGMENTS (Total Duration: #{total_duration.round(1)} seconds):
    PROMPT

    segments.each_with_index do |segment, index|
      start_time = segment[:start_time] || segment['start'] || 0
      end_time = segment[:end_time] || segment['end'] || 0
      text = segment[:text] || segment['text'] || ''
      
      prompt += <<~SEGMENT
        Segment #{index + 1} (#{start_time.round(1)}s - #{end_time.round(1)}s): "#{text.strip}"
      SEGMENT
    end

    prompt += <<~PROMPT
      TASK: Analyze each segment and generate 1-2 specific image search queries for each segment that would create compelling visual accompaniment for a Ken Burns-style video effect.

      REQUIREMENTS:
      - Generate 2-3 queries PER SEGMENT PLUS backup options
      - CATEGORIZE each query as either "famous_person", "stock_image", or "general"
      - For FAMOUS PERSONS (politicians, celebrities, historical figures, public figures): Use category "famous_person"
      - For STOCK IMAGES (landscapes, objects, generic scenes, concepts): Use category "stock_image"  
      - For GENERAL CONTENT (mixed or unclear): Use category "general"
      - Generate queries that are HIGHLY specific and descriptive
      - Focus on concrete visual elements mentioned or implied in each segment's text
      - Consider the emotional tone and context of each segment
      - TIMING AWARENESS: Consider each segment's position in the narrative flow
      - Match images to the EXACT moment being described in each time segment
      - For segments with multiple concepts, prioritize the most visually prominent element
      - Avoid generic terms, be specific about objects, scenes, or concepts
      - Each query should be 3-8 words for better specificity
      - Prioritize queries that would work well for Ken Burns effects (landscapes, objects, people, etc.)
      - Always include backup/fallback queries for each segment
      - Provide alternative search terms that could work if primary queries fail
      - Ensure images can sustain viewer attention for 5-11 seconds without being repetitive

      RESPONSE FORMAT (JSON only):
      {
        "segments": [
          {
            "segment_id": 0,
            "image_queries": [
              {"query": "primary specific query", "category": "famous_person"},
              {"query": "secondary query", "category": "stock_image"},
              {"query": "fallback query", "category": "general"}
            ],
            "backup_queries": ["alternative term 1", "alternative term 2"]
          },
          {
            "segment_id": 1,
            "image_queries": [
              {"query": "primary specific query", "category": "stock_image"},
              {"query": "secondary query", "category": "general"},
              {"query": "fallback query", "category": "famous_person"}
            ],
            "backup_queries": ["alternative term 1", "alternative term 2"]
          }
        ],
        "primary_theme": "brief description of main theme",
        "visual_style": "#{style}",
        "total_duration": #{total_duration.round(1)}
      }

      Generate only the JSON response, no other text. Provide image_queries for each segment with proper categorization.
    PROMPT

    prompt
  end

  # Parse batch analysis response from Gemini
  # @param response [Hash] Gemini API response
  # @param segments [Array] Transcribed audio segments
  # @return [Array] Enriched segments with image queries
  def parse_batch_analysis_response(response, segments)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    
    return segments unless content
    
    begin
      # Clean up markdown code blocks if present
      cleaned_content = content.strip
      # Remove markdown code blocks
      cleaned_content = cleaned_content.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      cleaned_content = cleaned_content.strip
      
      # Try to parse as JSON
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      
      # Check if we have the new format with segments
      if parsed[:segments] && parsed[:segments].is_a?(Array)
        # New format: each segment has its own queries
        enriched_segments = segments.map.with_index do |segment, index|
          segment_analysis = parsed[:segments].find { |s| s[:segment_id] == index }
          
          if segment_analysis && segment_analysis[:image_queries]
            # Handle both old string format and new categorized format
            processed_queries = segment_analysis[:image_queries].map do |query_item|
              if query_item.is_a?(Hash) && query_item[:query] && query_item[:category]
                # New categorized format
                {
                  query: query_item[:query].to_s.strip,
                  category: query_item[:category].to_s.strip
                }
              elsif query_item.is_a?(String)
                # Old string format - default to general category
                {
                  query: query_item.to_s.strip,
                  category: 'general'
                }
              else
                # Fallback
                {
                  query: query_item.to_s.strip,
                  category: 'general'
                }
              end
            end.reject { |q| q[:query].empty? }
            
            # Extract backup queries if available
            backup_queries = segment_analysis[:backup_queries] || []
            clean_backup_queries = backup_queries.map do |query|
              query.to_s.gsub(/^["\s]*/, '').gsub(/["\s]*$/, '').gsub(/^backup_queries":\s*\[?"?/, '').gsub(/"?\s*,?\s*$/, '')
            end.reject(&:empty?)
            
            segment.merge({
              image_queries: processed_queries,
              backup_queries: clean_backup_queries,
              has_images: processed_queries.any?
            })
          else
            # Fallback: generate queries for this segment
            fallback_queries = generate_fallback_queries(segment[:text] || segment['text'] || '')
            segment.merge({
              image_queries: fallback_queries,
              backup_queries: generate_fallback_queries(segment[:text] || segment['text'] || ''),
              has_images: true
            })
          end
        end
        
        enriched_segments
      else
        # Old format: distribute queries across segments
        image_queries = parsed[:image_queries] || []
        distribute_image_queries(segments, image_queries)
      end
    rescue JSON::ParserError
      # Fallback: try to extract queries from text
      fallback_queries = extract_queries_from_text(content)
      distribute_image_queries(segments, fallback_queries)
    end
  end

  # Distribute image queries across segments
  # @param segments [Array] Audio segments
  # @param image_queries [Array] Image queries
  # @return [Array] Segments with assigned queries
  def distribute_image_queries(segments, image_queries)
    return segments if image_queries.empty?
    
    segments.each_with_index do |segment, index|
      # Assign ONE query per segment based on segment position
      query_index = index % image_queries.length
      # Preserve all original segment data and add ONE image query
      segment.merge!({
        image_queries: [image_queries[query_index]], # Only ONE query per segment
        has_images: true
      })
    end
    
    segments
  end
end