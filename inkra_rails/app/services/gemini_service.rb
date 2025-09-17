class GeminiService
  def initialize
    @service = InterviewQuestionService.new
  end
  
  def polish_transcript(transcript:, perspective:, speaker_name:, pronoun: nil)
    Rails.logger.info "Polishing transcript with perspective: #{perspective}"
    
    prompt = build_polishing_prompt(transcript, perspective, speaker_name, pronoun)
    response = @service.send(:make_gemini_request, prompt)
    
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return nil unless content
    
    content.strip
  rescue => e
    Rails.logger.error "Failed to polish transcript: #{e.message}"
    nil
  end
  
  def analyze_content(prompt)
    Rails.logger.info "Analyzing content with Gemini"
    
    response = @service.send(:make_gemini_request, prompt)
    
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return nil unless content
    
    content.strip
  rescue => e
    Rails.logger.error "Failed to analyze content: #{e.message}"
    nil
  end
  
  private
  
  def build_polishing_prompt(transcript, perspective, speaker_name, pronoun)
    perspective_instructions = case perspective
    when 'first_person'
      "Write in first person (I/me/my). Convert all references to the speaker into first person."
    when 'second_person'
      "Write in second person (you/your). This is already the natural perspective for interviews."
    when 'third_person'
      possessive = case pronoun
                    when 'he' then 'his'
                    when 'she' then 'her'
                    else 'their'
                    end
      "Write in third person using '#{speaker_name}' and '#{pronoun}/#{possessive}'. Convert all 'I/me/my' references to third person."
    end
    
    <<~PROMPT
      You are an expert editor polishing an interview transcript. Your task is to create a polished, readable version while maintaining authenticity.
      
      SPEAKER: #{speaker_name}
      PERSPECTIVE: #{perspective}
      
      RAW TRANSCRIPT:
      #{transcript}
      
      INSTRUCTIONS:
      1. #{perspective_instructions}
      2. Remove filler words (um, uh, like, you know) while preserving natural speech patterns
      3. Fix grammar and punctuation while maintaining the speaker's voice
      4. Break into logical paragraphs for readability
      5. Preserve all important details, stories, and emotions
      6. Keep the conversational, warm tone appropriate for family memories
      7. Ensure the text flows naturally and is engaging to read
      
      IMPORTANT:
      - Maintain the exact perspective requested (#{perspective})
      - Keep the authentic voice of the speaker
      - Preserve all meaningful content and stories
      - Return only the polished text, no additional formatting or comments
      
      Return the polished text directly, formatted as clean paragraphs.
    PROMPT
  end
end