class GeminiTextPolishingService
  def self.polish_transcript(raw_content)
    return "" if raw_content.blank?
    
    begin
      Rails.logger.info "Starting Gemini text polishing"
      
      # Use raw plaintext directly if it's a string, otherwise extract from structured content
      raw_text = raw_content.is_a?(String) ? raw_content : extract_text_from_structured_content(raw_content)
      return "" if raw_text.blank?
      
      # Call Gemini API for polishing
      service = InterviewQuestionService.new
      prompt = build_polishing_prompt(raw_text)
      response = service.send(:make_gemini_request, prompt)
      
      # Parse the Gemini response
      content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      return "" unless content
      
      # Return polished content as plain text
      polished_text = content.strip
      
      Rails.logger.info "Gemini polishing successful"
      polished_text
      
    rescue => e
      Rails.logger.error "Gemini polishing failed: #{e.message}"
      ""
    end
  end

  # Legacy method for backward compatibility
  def self.polish_transcript_structured(raw_structured_content)
    return [] if raw_structured_content.blank?
    
    begin
      Rails.logger.info "Starting Gemini text polishing (structured)"
      
      # Extract text from structured content
      raw_text = extract_text_from_structured_content(raw_structured_content)
      return [] if raw_text.blank?
      
      # Call Gemini API for polishing
      service = InterviewQuestionService.new
      prompt = build_structured_polishing_prompt(raw_text)
      response = service.send(:make_gemini_request, prompt)
      
      # Parse the Gemini response
      content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      return [] unless content
      
      # Extract polished content from JSON response
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      
      polished_content = parsed[:content] || []
      
      Rails.logger.info "Gemini polishing successful: #{polished_content.length} content items"
      polished_content
      
    rescue => e
      Rails.logger.error "Gemini polishing failed: #{e.message}"
      []
    end
  end

  private

  def self.extract_text_from_structured_content(structured_content)
    return "" unless structured_content.is_a?(Array)
    
    text_parts = []
    current_context = {}
    
    structured_content.each do |item|
      case item['type']
      when 'chapter'
        current_context[:chapter] = item['title']
        text_parts << "\n\n## #{item['title']}\n" if item['title']
      when 'section'
        current_context[:section] = item['title']
        text_parts << "\n### #{item['title']}\n" if item['title']
      when 'paragraph'
        if item['text']
          # Add context for better polishing
          context_prefix = ""
          if current_context[:chapter] && current_context[:section]
            context_prefix = "[#{current_context[:chapter]} - #{current_context[:section]}] "
          elsif current_context[:chapter]
            context_prefix = "[#{current_context[:chapter]}] "
          end
          
          text_parts << "#{context_prefix}#{item['text']}\n"
        end
      end
    end
    
    text_parts.join
  end

  def self.build_polishing_prompt(raw_text)
    <<~PROMPT
      You are an expert transcript editor. Your task is to polish this raw interview transcript into professional, well-structured content while maintaining the authentic voice and all important details.

      RAW TRANSCRIPT:
      #{raw_text}

      INSTRUCTIONS:
      1. Clean up filler words (um, uh, like, you know) but preserve natural speech patterns and the original language as much as possible
      2. Fix grammar, punctuation, and sentence structure while maintaining the speaker's natural voice
      3. Improve flow and readability while maintaining conversational tone
      4. Break content into logical paragraphs based on topics and natural transitions
      5. Preserve all key details, examples, and specific information mentioned
      6. Maintain the structure indicated by chapter/section headers and interview questions
      7. Ensure each paragraph is substantial and well-formed
      8. Keep the content interview-appropriate (professional but authentic)
      9. Include interview questions in the polished output to provide context
      10. Preserve the original language and cultural expressions as much as possible

      OUTPUT FORMAT:
      Return the polished content as clean, well-formatted markdown text. Maintain the chapter/section structure and include interview questions. Do not return JSON - just return the polished markdown text directly.

      IMPORTANT:
      - Return only the polished markdown text, no other formatting or wrapper text
      - Maintain the logical structure from the raw content
      - Each paragraph should be meaningful and substantial
      - Preserve the essence and details of what was said
      - Include interview questions to provide context for responses
      - Keep the speaker's authentic voice and original language
    PROMPT
  end

  def self.build_structured_polishing_prompt(raw_text)
    <<~PROMPT
      You are an expert transcript editor. Your task is to polish this raw interview transcript into professional, well-structured content while maintaining the authentic voice and all important details.

      RAW TRANSCRIPT:
      "#{raw_text}"

      INSTRUCTIONS:
      1. Clean up filler words (um, uh, like, you know) but preserve natural speech patterns
      2. Fix grammar, punctuation, and sentence structure
      3. Improve flow and readability while maintaining conversational tone
      4. Break content into logical paragraphs based on topics and natural transitions
      5. Preserve all key details, examples, and specific information mentioned
      6. Maintain the structure indicated by chapter/section headers
      7. Ensure each paragraph is substantial and well-formed
      8. Keep the content interview-appropriate (professional but authentic)

      OUTPUT FORMAT:
      Return the polished content as a JSON array where each item represents a content block. Use this exact structure:

      {
        "content": [
          {
            "type": "chapter",
            "chapterId": null,
            "title": "Chapter Title Here",
            "text": null,
            "audioSegmentId": null
          },
          {
            "type": "section", 
            "sectionId": null,
            "title": "Section Title Here",
            "text": null,
            "audioSegmentId": null
          },
          {
            "type": "paragraph",
            "chapterId": null,
            "sectionId": null,
            "questionId": null,
            "text": "Polished paragraph text here. This should be well-structured, grammatically correct, and flow naturally.",
            "audioSegmentId": null
          }
        ]
      }

      IMPORTANT:
      - Only return the JSON response, no other text
      - Maintain the logical structure from the raw content
      - Each paragraph should be meaningful and substantial
      - Preserve the essence and details of what was said
      - IDs will be populated later by the system, keep them null
    PROMPT
  end
end