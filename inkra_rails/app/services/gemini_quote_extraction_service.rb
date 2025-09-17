class GeminiQuoteExtractionService
  def self.extract_quotes(transcript, orientation = 'portrait')
    Rails.logger.info "🟢 GeminiQuoteService: Starting extraction with #{transcript&.length || 0} chars, orientation: #{orientation}"
    
    return { quotes: [], searchTerms: [], imagePrompts: [] } if transcript.blank?
    
    begin
      Rails.logger.info "🔵 GeminiQuoteService: Building extraction prompt"
      
      # Call Gemini API for quote extraction
      service = InterviewQuestionService.new
      prompt = build_quote_extraction_prompt(transcript, orientation)
      
      Rails.logger.info "🔵 GeminiQuoteService: Prompt length: #{prompt.length} chars"
      Rails.logger.info "🔵 GeminiQuoteService: Making Gemini API request"
      
      response = service.send(:make_gemini_request, prompt)
      
      Rails.logger.info "🔵 GeminiQuoteService: Received Gemini response"
      Rails.logger.info "🔵 GeminiQuoteService: Response structure: #{response&.keys&.join(', ')}"
      
      # Parse the Gemini response
      content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      
      unless content
        Rails.logger.warn "⚠️ GeminiQuoteService: No content in Gemini response"
        Rails.logger.warn "⚠️ GeminiQuoteService: Full response: #{response.inspect}"
        return { quotes: [], searchTerms: [], imagePrompts: [] }
      end
      
      Rails.logger.info "🔵 GeminiQuoteService: Raw content length: #{content.length} chars"
      Rails.logger.info "🔵 GeminiQuoteService: Raw content preview: #{content[0..200]}..."
      
      # Clean up and parse JSON response
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      Rails.logger.info "🔵 GeminiQuoteService: Cleaned content length: #{cleaned_content.length} chars"
      
      begin
        parsed = JSON.parse(cleaned_content, symbolize_names: true)
        Rails.logger.info "🟢 GeminiQuoteService: Successfully parsed JSON response"
      rescue JSON::ParserError => json_error
        Rails.logger.error "🔴 GeminiQuoteService: JSON parsing failed: #{json_error.message}"
        Rails.logger.error "🔴 GeminiQuoteService: Content that failed to parse: #{cleaned_content}"
        return { quotes: [], searchTerms: [], imagePrompts: [] }
      end
      
      result = {
        quotes: parsed[:quotes] || [],
        orientation: parsed[:orientation] || orientation,
        searchTerms: parsed[:searchTerms] || [],
        imagePrompts: parsed[:imagePrompts] || []
      }
      
      Rails.logger.info "🟢 GeminiQuoteService: Extraction successful - quotes: #{result[:quotes].length}, searchTerms: #{result[:searchTerms].length}, imagePrompts: #{result[:imagePrompts].length}"
      
      # Log quote details for debugging
      result[:quotes].each_with_index do |quote, index|
        Rails.logger.info "🔵 GeminiQuoteService: Quote #{index + 1}: '#{quote[:text]&.slice(0, 50)}...' (#{quote[:colorizedWords]&.length || 0} colored words)"
      end
      
      result
      
    rescue => e
      Rails.logger.error "🔴 GeminiQuoteService: Extraction failed: #{e.class.name} - #{e.message}"
      Rails.logger.error "🔴 GeminiQuoteService: Full backtrace: #{e.backtrace&.join('\n')}"
      
      # Check if this is a network/API error vs parsing error
      if e.message.include?('timeout') || e.message.include?('connection')
        Rails.logger.error "🔴 GeminiQuoteService: Network/timeout error detected"
      elsif e.is_a?(JSON::ParserError)
        Rails.logger.error "🔴 GeminiQuoteService: JSON parsing error detected"
      else
        Rails.logger.error "🔴 GeminiQuoteService: Unknown error type: #{e.class.name}"
      end
      
      { quotes: [], searchTerms: [], imagePrompts: [] }
    end
  end

  private

  def self.build_quote_extraction_prompt(transcript, orientation)
    max_length = orientation == 'portrait' ? 120 : 180
    
    <<~PROMPT
      You are an expert at extracting powerful, shareable quotes from interview transcripts for social media quote graphics.

      TASK: Analyze this interview transcript and extract 3-5 compelling quotes that would work well as quote shots.

      TRANSCRIPT:
      #{transcript}

      REQUIREMENTS:
      - Each quote should be #{max_length} characters or less for #{orientation} format
      - Focus on the most impactful, emotional, or insightful statements
      - Quotes should be complete thoughts that work independently
      - Prioritize quotes that are relatable and shareable
      - Remove filler words like "um", "uh", "you know"
      - Fix minor grammar issues while preserving the speaker's voice
      - For each quote, identify 2-3 key words that should be highlighted in a different color
      - Generate 3-5 relevant image search terms for finding appropriate background images
      - Generate 3 detailed image generation prompts that would create suitable backgrounds for these quotes

      RESPONSE FORMAT (JSON only):
      {
        "quotes": [
          {
            "text": "The exact quote text here",
            "reasoning": "Why this quote is compelling",
            "colorizedWords": [
              {
                "word": "powerful",
                "color": "#FF6B35",
                "range": {"location": 15, "length": 8}
              },
              {
                "word": "moment",
                "color": "#4A90E2", 
                "range": {"location": 45, "length": 6}
              }
            ],
            "estimatedReadingTime": 3.5
          }
        ],
        "orientation": "#{orientation}",
        "searchTerms": [
          "inspirational sunrise",
          "person thinking deeply",
          "calm nature scene"
        ],
        "imagePrompts": [
          "A serene sunrise over mountains with warm golden light, inspirational mood, high quality photography",
          "Abstract geometric patterns with flowing gradients in purple and blue tones, modern minimal design",
          "Peaceful ocean waves at sunset with soft pastel colors, calming atmosphere, professional photography"
        ]
      }

      COLORIZATION GUIDELINES:
      - Highlight emotional words (love, fear, hope, dream, etc.) in warm colors (#FF6B35, #E74C3C)
      - Highlight action words (create, build, achieve, etc.) in energetic colors (#3498DB, #9B59B6)
      - Highlight important nouns in accent colors (#2ECC71, #F39C12)
      - Use maximum 3 colors per quote to avoid overwhelming the design
      - Ensure colors contrast well with both light and dark backgrounds

      Generate only the JSON response, no other text.
    PROMPT
  end
end