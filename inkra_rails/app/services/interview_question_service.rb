require 'net/http'
require 'json'

class InterviewQuestionService
  GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    @model = 'gemini-2.5-flash-lite'
    @max_tokens = 2048
    @temperature = 0.7
    
    raise "GEMINI_API_KEY environment variable not set" unless @api_key
  end

  # Generate interview questions for a given topic
  # @param topic [String] The topic for interview questions
  # @param options [Hash] Generation options
  # @return [Hash] Structured interview outline
  def generate_interview_outline(topic, options = {})
    # Use options if provided, otherwise use defaults
    num_chapters = options[:num_chapters] || 1
    sections_per_chapter = options[:sections_per_chapter] || 1
    questions_per_section = options[:questions_per_section] || 10
    
    prompt = build_interview_outline_prompt(topic, num_chapters, sections_per_chapter, questions_per_section)
    
    response = make_gemini_request(prompt)
    parse_interview_outline_response(response)
  end

  # Generate additional questions for a specific section
  # @param section_context [Hash] Context about the section
  # @param num_questions [Integer] Number of questions to generate
  # @return [Array] Additional questions
  def generate_section_questions(section_context, num_questions = 3)
    prompt = build_section_questions_prompt(section_context, num_questions)
    
    response = make_gemini_request(prompt)
    parse_section_questions_response(response)
  end

  # Refine existing questions based on feedback
  # @param questions [Array] Existing questions
  # @param feedback [String] Feedback for improvement
  # @return [Array] Refined questions
  def refine_questions(questions, feedback)
    prompt = build_question_refinement_prompt(questions, feedback)
    
    response = make_gemini_request(prompt)
    parse_refined_questions_response(response)
  end

  # Generate follow-up questions based on user's answer
  # @param original_question_text [String] The original question
  # @param user_answer [String] The user's answer
  # @return [Array] Follow-up questions
  def generate_followup_questions(original_question_text:, user_answer:)
    prompt = build_followup_prompt(original_question_text, user_answer)
    response = make_gemini_request(prompt)
    parse_followup_response(response)
  end

  # Generate additional chapters for an existing project
  # @param project [Project] The project to expand
  # @return [Hash] Additional chapters structure
  def generate_additional_chapters(project)
    prompt = build_additional_chapters_prompt(project)
    response = make_gemini_request(prompt)
    parse_interview_outline_response(response)
  end

  # Generate interview questions based on tracker context
  # @param tracker_name [String] The name of the tracker
  # @param tracker_context [String] The context from tracker entries
  # @return [Hash] Structured interview outline
  def generate_interview_from_tracker(tracker_name, tracker_context)
    prompt = build_tracker_interview_prompt(tracker_name, tracker_context)
    response = make_gemini_request(prompt)
    parse_interview_outline_response(response)
  end
  
  # Generate additional questions for unlimited interview mode
  # @param context [Hash] Context including existing questions and answers
  # @param num_questions [Integer] Number of questions to generate
  # @return [Array] Additional question texts
  def generate_additional_questions_for_unlimited(context, num_questions = 20)
    prompt = build_unlimited_questions_prompt(context, num_questions)
    response = make_gemini_request(prompt)
    parse_unlimited_questions_response(response)
  end

  private

  def build_interview_outline_prompt(topic, num_chapters, sections_per_chapter, questions_per_section)
    <<~PROMPT
      You are an expert interview designer creating a comprehensive interview outline.

      TOPIC: #{topic}

      TASK: Create a structured interview outline with:
      - #{num_chapters} chapters (main themes/areas)
      - #{sections_per_chapter} sections per chapter (sub-topics)
      - #{questions_per_section} questions per section (specific interview questions)

      REQUIREMENTS:
      - Questions should be open-ended and thought-provoking
      - Progress from general to specific within each section
      - Ensure logical flow between chapters and sections
      - Questions should encourage detailed, personal responses
      - Avoid yes/no questions
      - Include follow-up question suggestions where appropriate
      - Make questions conversational and engaging

      RESPONSE FORMAT (JSON only):
      {
        "title": "Interview about [topic]",
        "chapters": [
          {
            "title": "Chapter title",
            "order": 1,
            "sections": [
              {
                "title": "Section title",
                "order": 1,
                "questions": [
                  {
                    "text": "Question text here?",
                    "order": 1
                  }
                ]
              }
            ]
          }
        ]
      }

      Generate only the JSON response, no other text.
    PROMPT
  end

  def build_section_questions_prompt(section_context, num_questions)
    chapter_title = section_context[:chapter_title]
    section_title = section_context[:section_title]
    existing_questions = section_context[:existing_questions] || []
    
    <<~PROMPT
      You are an expert interview designer adding questions to an existing section.

      CONTEXT:
      Chapter: #{chapter_title}
      Section: #{section_title}
      
      EXISTING QUESTIONS:
      #{existing_questions.map.with_index { |q, i| "#{i + 1}. #{q}" }.join("\n")}

      TASK: Generate #{num_questions} additional interview questions for this section that:
      - Complement the existing questions without being repetitive
      - Maintain the same theme and depth level
      - Are open-ended and encourage detailed responses
      - Flow naturally with the existing questions

      RESPONSE FORMAT (JSON only):
      {
        "questions": [
          {
            "text": "Question text here?",
            "order": #{existing_questions.length + 1}
          }
        ]
      }

      Generate only the JSON response, no other text.
    PROMPT
  end

  def build_question_refinement_prompt(questions, feedback)
    <<~PROMPT
      You are an expert interview designer refining questions based on feedback.

      CURRENT QUESTIONS:
      #{questions.map.with_index { |q, i| "#{i + 1}. #{q[:text] || q['text']}" }.join("\n")}

      FEEDBACK: #{feedback}

      TASK: Refine the questions based on the feedback while maintaining:
      - The overall intent and structure
      - Open-ended nature that encourages detailed responses
      - Logical flow and progression
      - Conversational tone

      RESPONSE FORMAT (JSON only):
      {
        "questions": [
          {
            "text": "Refined question text here?",
            "order": 1
          }
        ]
      }

      Generate only the JSON response, no other text.
    PROMPT
  end

  def build_followup_prompt(original_question, answer)
    <<~PROMPT
    You are an expert interviewer. Based on the user's answer to an original question, generate 1 to 3 insightful, open-ended follow-up questions. The goal is to dig deeper into the user's response, clarify points, or explore related tangents.

    ORIGINAL QUESTION:
    "#{original_question}"

    USER'S ANSWER:
    "#{answer}"

    TASK:
    Generate 1 to 3 follow-up questions.

    RESPONSE FORMAT (JSON only):
    {
      "questions": [
        { "text": "First follow-up question?" },
        { "text": "Second follow-up question?" }
      ]
    }

    Generate only the JSON response, no other text.
    PROMPT
  end

  def build_additional_chapters_prompt(project)
    existing_chapters = project.chapters.includes(sections: :questions).map do |chapter|
      {
        title: chapter.title,
        sections: chapter.sections.map do |section|
          {
            title: section.title,
            questions: section.questions.base_questions.map(&:text)
          }
        end
      }
    end

    # Get interview context from transcripts/audio segments
    interview_context = ""
    if project.audio_segments.any?
      recent_transcripts = project.audio_segments
                                 .where.not(transcription_text: [nil, ""])
                                 .limit(10)
                                 .pluck(:transcription_text)
      interview_context = recent_transcripts.join("\n\n")
    end

    <<~PROMPT
      You are an expert interview designer creating additional chapters for an existing interview project.

      ORIGINAL TOPIC: #{project.topic}

      EXISTING CHAPTERS AND STRUCTURE:
      #{existing_chapters.map.with_index do |chapter, i|
        sections_text = chapter[:sections].map.with_index do |section, j|
          questions_text = section[:questions].map.with_index { |q, k| "        #{k + 1}. #{q}" }.join("\n")
          "    Section #{j + 1}: #{section[:title]}\n#{questions_text}"
        end.join("\n")
        "Chapter #{i + 1}: #{chapter[:title]}\n#{sections_text}"
      end.join("\n\n")}

      #{"INTERVIEW CONTEXT (from recent recordings):\n#{interview_context}\n\n" if interview_context.present?}

      TASK: Generate 2-3 additional chapters that:
      - Expand on the original topic without repeating existing content
      - Complement the existing chapters by exploring new angles or deeper aspects
      - Follow the same structure (2 sections per chapter, 3 questions per section)
      - Take into account any themes or insights from the interview context
      - Are logically ordered as a continuation of the existing outline
      - Maintain the same depth and interview style as existing questions

      REQUIREMENTS:
      - Questions should be open-ended and thought-provoking
      - Avoid any overlap with existing chapters/sections/questions
      - Build upon themes that may have emerged from the interview context
      - Ensure smooth progression from the existing content
      - Use the next available order numbers for chapters

      RESPONSE FORMAT (JSON only):
      {
        "chapters": [
          {
            "title": "New chapter title",
            "order": #{existing_chapters.length + 1},
            "sections": [
              {
                "title": "Section title",
                "order": 1,
                "questions": [
                  {
                    "text": "Question text here?",
                    "order": 1
                  }
                ]
              }
            ]
          }
        ]
      }

      Generate only the JSON response, no other text.
    PROMPT
  end

  def build_tracker_interview_prompt(tracker_name, tracker_context)
    <<~PROMPT
      You are an expert interview designer creating a personalized interview based on tracker data.

      TRACKER NAME: #{tracker_name}

      TRACKER CONTEXT (recent entries):
      #{tracker_context}

      TASK: Create a structured interview outline with:
      - 3 chapters (main themes/areas) that explore the user's experience with this tracker
      - 2 sections per chapter (sub-topics)
      - 3 questions per section (specific interview questions)

      REQUIREMENTS:
      - Questions should be deeply personalized based on the tracker context provided
      - Explore patterns, insights, and reflections related to the tracking data
      - Questions should be open-ended and encourage detailed, personal responses
      - Progress from general reflection to specific insights within each section
      - Reference specific patterns or themes from the tracker entries when relevant
      - Avoid yes/no questions
      - Make questions conversational and engaging
      - Help the user reflect on their journey and growth in this area

      CHAPTER THEMES TO CONSIDER:
      - Patterns and trends in the tracking data
      - Personal insights and realizations
      - Challenges and breakthroughs
      - Future goals and aspirations related to this area

      RESPONSE FORMAT (JSON only):
      {
        "title": "Reflection on Your #{tracker_name} Journey",
        "chapters": [
          {
            "title": "Chapter title",
            "order": 1,
            "sections": [
              {
                "title": "Section title",
                "order": 1,
                "questions": [
                  {
                    "text": "Question text here?",
                    "order": 1
                  }
                ]
              }
            ]
          }
        ]
      }

      Generate only the JSON response, no other text.
    PROMPT
  end

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

  def parse_interview_outline_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return { error: 'No content in response' } unless content

    begin
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      JSON.parse(cleaned_content, symbolize_names: true)
    rescue JSON::ParserError => e
      { error: "Failed to parse response: #{e.message}", raw_content: content }
    end
  end

  def parse_section_questions_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return [] unless content

    begin
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      parsed[:questions] || []
    rescue JSON::ParserError
      []
    end
  end

  def parse_refined_questions_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return [] unless content

    begin
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      parsed[:questions] || []
    rescue JSON::ParserError
      []
    end
  end

  def parse_followup_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return [] unless content

    begin
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      parsed[:questions] || []
    rescue JSON::ParserError
      []
    end
  end
  
  def build_unlimited_questions_prompt(context, num_questions)
    existing_questions_text = context[:existing_questions].join("\n- ")
    
    answered_context = if context[:answered_questions].present?
      context[:answered_questions].map do |qa|
        "Q: #{qa[:question]}\nA: #{qa[:answer]}"
      end.join("\n\n")
    else
      "No questions answered yet"
    end
    
    <<~PROMPT
      You are an expert interviewer continuing an in-depth interview session.
      
      INTERVIEW TOPIC: #{context[:topic]}
      
      EXISTING QUESTIONS ALREADY ASKED:
      - #{existing_questions_text}
      
      CONTEXT FROM ANSWERED QUESTIONS:
      #{answered_context}
      
      TASK: Generate #{num_questions} NEW interview questions that:
      - Continue exploring the topic in greater depth
      - Build on themes that emerged from the answers given
      - DO NOT repeat or rephrase any existing questions
      - Maintain the conversational and engaging tone
      - Progress naturally from what has been discussed
      - Explore new angles and perspectives
      - Remain relevant to the original topic
      
      REQUIREMENTS:
      - All questions must be unique and not covered before
      - Questions should be open-ended and thought-provoking
      - Consider the flow and context of the conversation so far
      - Mix both follow-up themes and entirely new aspects
      - Maintain interview quality and depth
      
      RESPONSE FORMAT (JSON only):
      {
        "questions": [
          "First new question text here?",
          "Second new question text here?",
          ...
        ]
      }
      
      Generate only the JSON response with exactly #{num_questions} new questions.
    PROMPT
  end
  
  def parse_unlimited_questions_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    return [] unless content
    
    begin
      cleaned_content = content.strip.gsub(/^```json\s*/, '').gsub(/\s*```$/, '')
      parsed = JSON.parse(cleaned_content, symbolize_names: true)
      parsed[:questions] || []
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse unlimited questions response: #{e.message}"
      []
    end
  end
end