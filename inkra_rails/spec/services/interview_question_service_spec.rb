require 'rails_helper'

RSpec.describe InterviewQuestionService, type: :service do
  let(:service) { described_class.new }
  let(:test_topic) { "Building a successful startup" }

  before do
    # Use actual GEMINI_KEY from environment for VCR recording
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return(ENV['GEMINI_KEY'])
  end

  describe '#generate_interview_outline', :vcr do
    context 'with valid topic' do
      it 'generates a structured interview outline' do
        VCR.use_cassette('interview_outline_generation') do
          result = service.generate_interview_outline(test_topic)

          expect(result).to be_a(Hash)
          expect(result[:title]).to include('Interview')
          expect(result[:chapters]).to be_an(Array)
          expect(result[:chapters].length).to eq(3)

          first_chapter = result[:chapters].first
          expect(first_chapter[:title]).to be_present
          expect(first_chapter[:order]).to eq(1)
          expect(first_chapter[:sections]).to be_an(Array)
          expect(first_chapter[:sections].length).to eq(2)

          first_section = first_chapter[:sections].first
          expect(first_section[:title]).to be_present
          expect(first_section[:order]).to eq(1)
          expect(first_section[:questions]).to be_an(Array)
          expect(first_section[:questions].length).to eq(3)

          first_question = first_section[:questions].first
          expect(first_question[:text]).to be_present
          expect(first_question[:text]).to end_with('?')
          expect(first_question[:order]).to eq(1)
        end
      end

      it 'respects custom options' do
        VCR.use_cassette('interview_outline_custom_options') do
          options = {
            num_chapters: 2,
            sections_per_chapter: 3,
            questions_per_section: 4
          }

          result = service.generate_interview_outline(test_topic, options)

          expect(result[:chapters].length).to eq(2)
          expect(result[:chapters].first[:sections].length).to eq(3)
          expect(result[:chapters].first[:sections].first[:questions].length).to eq(4)
        end
      end
    end

    context 'when API returns error' do
      it 'handles API errors gracefully' do
        allow(service).to receive(:make_gemini_request).and_raise('Gemini API Error: Rate limit exceeded')

        expect { service.generate_interview_outline(test_topic) }.to raise_error(/Gemini API Error/)
      end
    end

    context 'when API returns malformed JSON' do
      it 'returns error response' do
        allow(service).to receive(:make_gemini_request).and_return({
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'Invalid JSON response' }
                ]
              }
            }
          ]
        })

        result = service.generate_interview_outline(test_topic)

        expect(result[:error]).to include('Failed to parse response')
        expect(result[:raw_content]).to eq('Invalid JSON response')
      end
    end
  end

  describe '#generate_section_questions', :vcr do
    let(:section_context) do
      {
        chapter_title: 'Early Days',
        section_title: 'The Initial Idea',
        existing_questions: [
          'What inspired you to start this venture?',
          'What problem were you trying to solve?'
        ]
      }
    end

    it 'generates additional questions for a section' do
      VCR.use_cassette('section_questions_generation') do
        result = service.generate_section_questions(section_context, 2)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        result.each do |question|
          expect(question[:text]).to be_present
          expect(question[:text]).to end_with('?')
          expect(question[:order]).to be > 2 # Should continue from existing questions
        end
      end
    end
  end

  describe '#refine_questions', :vcr do
    let(:questions) do
      [
        { text: 'What is your company?', id: 1 },
        { text: 'Do you like business?', id: 2 }
      ]
    end
    let(:feedback) { 'Make questions more open-ended and specific' }

    it 'refines questions based on feedback' do
      VCR.use_cassette('question_refinement') do
        result = service.refine_questions(questions, feedback)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        result.each do |question|
          expect(question[:text]).to be_present
          expect(question[:text]).to end_with('?')
          expect(question[:order]).to be_present
        end
      end
    end
  end

  describe 'error handling' do
    context 'when GEMINI_API_KEY is not set' do
      it 'raises an error' do
        allow(ENV).to receive(:[]).with('GEMINI_API_KEY').and_return(nil)

        expect { described_class.new }.to raise_error(/GEMINI_API_KEY environment variable not set/)
      end
    end

    context 'when HTTP request fails' do
      it 'raises appropriate error' do
        allow(service).to receive(:make_request).and_raise('Request failed: Connection timeout')

        expect { service.generate_interview_outline(test_topic) }.to raise_error(/Request failed/)
      end
    end
  end

  describe 'private methods' do
    describe '#parse_interview_outline_response' do
      context 'with valid JSON response' do
        let(:response) do
          {
            'candidates' => [
              {
                'content' => {
                  'parts' => [
                    {
                      'text' => '{"title": "Test Interview", "chapters": []}'
                    }
                  ]
                }
              }
            ]
          }
        end

        it 'parses response correctly' do
          result = service.send(:parse_interview_outline_response, response)

          expect(result[:title]).to eq('Test Interview')
          expect(result[:chapters]).to eq([])
        end
      end

      context 'with markdown-wrapped JSON' do
        let(:response) do
          {
            'candidates' => [
              {
                'content' => {
                  'parts' => [
                    {
                      'text' => "```json\n{\"title\": \"Test Interview\", \"chapters\": []}\n```"
                    }
                  ]
                }
              }
            ]
          }
        end

        it 'strips markdown and parses correctly' do
          result = service.send(:parse_interview_outline_response, response)

          expect(result[:title]).to eq('Test Interview')
          expect(result[:chapters]).to eq([])
        end
      end

      context 'with empty response' do
        let(:response) { {} }

        it 'returns error' do
          result = service.send(:parse_interview_outline_response, response)

          expect(result[:error]).to eq('No content in response')
        end
      end
    end
  end
end