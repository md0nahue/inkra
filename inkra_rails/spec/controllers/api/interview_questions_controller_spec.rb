require 'rails_helper'

RSpec.describe Api::InterviewQuestionsController, type: :controller do
  before do
    # Skip authentication for tests
    allow(controller).to receive(:authenticate_request!)
    
    # Mock the InterviewQuestionService to avoid real API calls in controller tests
    @mock_service = instance_double(InterviewQuestionService)
    allow(InterviewQuestionService).to receive(:new).and_return(@mock_service)
  end

  describe 'POST #generate_outline' do
    let(:topic) { 'Building a successful startup' }
    let(:valid_params) do
      {
        topic: topic,
        num_chapters: 3,
        sections_per_chapter: 2,
        questions_per_section: 3
      }
    end

    let(:mock_outline) do
      {
        title: 'Interview about Building a successful startup',
        chapters: [
          {
            title: 'The Beginning',
            order: 1,
            sections: [
              {
                title: 'Initial Idea',
                order: 1,
                questions: [
                  { text: 'What inspired your startup idea?', order: 1 },
                  { text: 'How did you validate the concept?', order: 2 },
                  { text: 'What problem were you solving?', order: 3 }
                ]
              }
            ]
          }
        ]
      }
    end

    context 'with valid parameters' do
      before do
        allow(@mock_service).to receive(:generate_interview_outline)
          .with(topic, { num_chapters: 3, sections_per_chapter: 2, questions_per_section: 3 })
          .and_return(mock_outline)
      end

      it 'generates interview outline successfully' do
        post :generate_outline, params: valid_params

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['outline']['title']).to include('Interview')
        expect(json_response['outline']['chapters']).to be_an(Array)
        expect(json_response['generated_at']).to be_present
      end

      it 'uses default values when optional parameters are missing' do
        allow(@mock_service).to receive(:generate_interview_outline)
          .with(topic, { num_chapters: 3, sections_per_chapter: 2, questions_per_section: 3 })
          .and_return(mock_outline)

        post :generate_outline, params: { topic: topic }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with missing topic' do
      it 'returns bad request error' do
        post :generate_outline, params: { num_chapters: 3 }

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Topic is required')
      end
    end

    context 'when service returns error' do
      before do
        allow(@mock_service).to receive(:generate_interview_outline)
          .and_return({ error: 'API rate limit exceeded' })
      end

      it 'returns unprocessable entity status' do
        post :generate_outline, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('API rate limit exceeded')
      end
    end

    context 'when service raises exception' do
      before do
        allow(@mock_service).to receive(:generate_interview_outline)
          .and_raise(StandardError.new('Connection timeout'))
      end

      it 'returns internal server error' do
        post :generate_outline, params: valid_params

        expect(response).to have_http_status(:internal_server_error)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to generate interview outline')
      end
    end
  end

  describe 'POST #generate_section_questions' do
    let!(:project) { create(:project_with_outline) }
    let!(:section) { project.chapters.first.sections.first }
    let(:valid_params) do
      {
        section_id: section.id,
        num_questions: 2
      }
    end

    let(:mock_questions) do
      [
        { text: 'What challenges did you face initially?', order: 4 },
        { text: 'How did you overcome those obstacles?', order: 5 }
      ]
    end

    context 'with valid section' do
      before do
        allow(@mock_service).to receive(:generate_section_questions)
          .and_return(mock_questions)
      end

      it 'generates additional questions for section' do
        post :generate_section_questions, params: valid_params

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['section_id']).to eq(section.id)
        expect(json_response['new_questions']).to match_array(
          mock_questions.map { |q| hash_including('text' => q[:text], 'order' => q[:order]) }
        )
        expect(json_response['generated_at']).to be_present
      end

      it 'uses default number of questions when not specified' do
        post :generate_section_questions, params: { section_id: section.id }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with non-existent section' do
      it 'returns not found error' do
        post :generate_section_questions, params: { section_id: 99999, num_questions: 2 }

        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Section not found')
      end
    end

    context 'when service raises exception' do
      before do
        allow(@mock_service).to receive(:generate_section_questions)
          .and_raise(StandardError.new('Service unavailable'))
      end

      it 'returns internal server error' do
        post :generate_section_questions, params: valid_params

        expect(response).to have_http_status(:internal_server_error)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to generate section questions')
      end
    end
  end

  describe 'POST #refine_questions' do
    let!(:project) { create(:project_with_outline) }
    let!(:questions) { project.questions.limit(2) }
    let(:valid_params) do
      {
        question_ids: questions.pluck(:id),
        feedback: 'Make the questions more specific and actionable'
      }
    end

    let(:mock_refined_questions) do
      [
        { text: 'What specific metrics did you use to validate your startup idea?', order: 1 },
        { text: 'Can you describe the exact steps you took to solve the initial problem?', order: 2 }
      ]
    end

    context 'with valid parameters' do
      before do
        allow(@mock_service).to receive(:refine_questions)
          .and_return(mock_refined_questions)
      end

      it 'refines questions successfully' do
        post :refine_questions, params: valid_params

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['original_questions']).to be_an(Array)
        expect(json_response['refined_questions']).to match_array(
          mock_refined_questions.map { |q| hash_including('text' => q[:text], 'order' => q[:order]) }
        )
        expect(json_response['feedback_applied']).to eq(valid_params[:feedback])
        expect(json_response['generated_at']).to be_present
      end
    end

    context 'with missing question_ids' do
      it 'returns bad request error' do
        post :refine_questions, params: { feedback: 'Make better' }

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Question IDs and feedback are required')
      end
    end

    context 'with missing feedback' do
      it 'returns bad request error' do
        post :refine_questions, params: { question_ids: [1, 2] }

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Question IDs and feedback are required')
      end
    end

    context 'with non-existent questions' do
      it 'returns not found error' do
        post :refine_questions, params: {
          question_ids: [99999, 99998],
          feedback: 'Make better'
        }

        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No questions found')
      end
    end
  end

  describe 'POST #create_project_from_outline' do
    let(:valid_params) do
      {
        title: 'My Startup Interview',
        topic: 'Building a tech startup',
        outline: {
          title: 'Interview about Building a tech startup',
          chapters: [
            {
              title: 'Early Days',
              order: 1,
              sections: [
                {
                  title: 'The Idea',
                  order: 1,
                  questions: [
                    { text: 'What was your initial idea?', order: 1 },
                    { text: 'How did you validate it?', order: 2 }
                  ]
                }
              ]
            }
          ]
        }
      }
    end

    context 'with valid outline data' do
      it 'creates project with complete structure' do
        expect {
          post :create_project_from_outline, params: valid_params
        }.to change(Project, :count).by(1)
          .and change(Chapter, :count).by(1)
          .and change(Section, :count).by(1)
          .and change(Question, :count).by(2)

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['project_id']).to be_present
        expect(json_response['title']).to eq('My Startup Interview')
        expect(json_response['status']).to eq('outline_ready')
        expect(json_response['message']).to include('successfully')

        # Verify the created structure
        project = Project.find(json_response['project_id'])
        expect(project.chapters.count).to eq(1)
        expect(project.chapters.first.sections.count).to eq(1)
        expect(project.chapters.first.sections.first.questions.count).to eq(2)
      end
    end

    context 'with missing required parameters' do
      it 'returns bad request for missing title' do
        params = valid_params.except(:title)
        
        post :create_project_from_outline, params: params

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Title, topic, and outline are required')
      end

      it 'returns bad request for missing topic' do
        params = valid_params.except(:topic)
        
        post :create_project_from_outline, params: params

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request for missing outline' do
        params = valid_params.except(:outline)
        
        post :create_project_from_outline, params: params

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when database operation fails' do
      before do
        allow(Project).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Project.new))
      end

      it 'returns internal server error' do
        post :create_project_from_outline, params: valid_params

        expect(response).to have_http_status(:internal_server_error)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to create project from outline')
      end
    end
  end

  describe 'POST #add_questions_to_section' do
    let!(:project) { create(:project_with_outline) }
    let!(:section) { project.chapters.first.sections.first }
    let(:valid_params) do
      {
        section_id: section.id,
        questions: [
          { text: 'What was your biggest mistake?' },
          { text: 'How did you recover from setbacks?' }
        ]
      }
    end

    context 'with valid parameters' do
      it 'adds questions to section successfully' do
        initial_count = section.questions.count

        expect {
          post :add_questions_to_section, params: valid_params
        }.to change(Question, :count).by(2)

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['section_id']).to eq(section.id)
        expect(json_response['added_questions'].count).to eq(2)
        expect(json_response['message']).to include('2 questions added successfully')

        # Verify questions were added with correct order
        section.reload
        new_questions = section.questions.order(:order).last(2)
        expect(new_questions.first.order).to be > initial_count
        expect(new_questions.last.order).to be > new_questions.first.order
      end
    end

    context 'with non-existent section' do
      it 'returns not found error' do
        params = valid_params.merge(section_id: 99999)
        
        post :add_questions_to_section, params: params

        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Section not found')
      end
    end

    context 'with empty questions data' do
      it 'returns bad request error' do
        params = valid_params.merge(questions: [])
        
        post :add_questions_to_section, params: params

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Questions data is required')
      end
    end

    context 'when database operation fails' do
      before do
        allow_any_instance_of(Section).to receive(:questions).and_raise(ActiveRecord::RecordInvalid.new(Question.new))
      end

      it 'returns internal server error' do
        post :add_questions_to_section, params: valid_params

        expect(response).to have_http_status(:internal_server_error)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Failed to add questions to section')
      end
    end
  end
end