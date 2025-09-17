require 'rails_helper'

RSpec.describe 'Api::Projects', type: :request do
  include_context "with authenticated user"

  let(:valid_project_params) do
    {
      project: {
        initialTopic: "My journey in technology"
      }
    }
  end

  let(:invalid_project_params) do
    {
      project: {
        initialTopic: ""
      }
    }
  end

  describe 'GET /api/projects' do
    context 'when user has projects' do
      let!(:projects) do
        [
          create(:project, user: current_user, title: "First Project", status: "completed", created_at: 2.days.ago),
          create(:project, user: current_user, title: "Second Project", status: "outline_ready", created_at: 1.day.ago),
          create(:project, user: current_user, title: "Third Project", status: "failed", created_at: 1.hour.ago)
        ]
      end

      before do
        # Create some chapters/sections for outline status
        create(:chapter, project: projects[1])
      end

      it 'returns all user projects ordered by last_modified_at desc' do
        get '/api/projects', headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data).to have_key('projects')
        expect(response_data['projects'].length).to eq(3)
        
        # Should be ordered by last_modified_at desc (most recent first)
        expect(response_data['projects'][0]['title']).to eq("Third Project")
        expect(response_data['projects'][1]['title']).to eq("Second Project")
        expect(response_data['projects'][2]['title']).to eq("First Project")
      end

      it 'includes proper project data structure' do
        get '/api/projects', headers: auth_headers
        
        response_data = JSON.parse(response.body)
        project_data = response_data['projects'].first
        
        expect(project_data).to include(
          'id', 'title', 'status', 'topic', 'createdAt', 'lastModifiedAt', 'outline'
        )
        
        expect(project_data['outline']).to include(
          'status', 'chaptersCount', 'sectionsCount', 'questionsCount'
        )
      end

      it 'includes correct outline counts' do
        get '/api/projects', headers: auth_headers
        
        response_data = JSON.parse(response.body)
        project_with_outline = response_data['projects'].find { |p| p['title'] == "Second Project" }
        
        expect(project_with_outline['outline']['chaptersCount']).to eq(1)
        expect(project_with_outline['outline']['sectionsCount']).to eq(0)
        expect(project_with_outline['outline']['questionsCount']).to eq(0)
      end
    end

    context 'when user has no projects' do
      it 'returns empty projects array' do
        get '/api/projects', headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['projects']).to eq([])
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/api/projects'
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/projects' do
    context 'with valid parameters' do
      it 'creates a new project' do
        expect {
          post '/api/projects', params: valid_project_params, headers: auth_headers
        }.to change(Project, :count).by(1)
        
        expect(response).to have_http_status(:created)
      end

      it 'returns correct project data' do
        post '/api/projects', params: valid_project_params, headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        expect(response_data).to include(
          'projectId', 'title', 'status', 'createdAt'
        )
        expect(response_data['title']).to eq("My journey in technology")
        expect(response_data['status']).to eq("outline_generating")
      end

      it 'associates project with current user' do
        post '/api/projects', params: valid_project_params, headers: auth_headers
        
        response_data = JSON.parse(response.body)
        project = Project.find(response_data['projectId'])
        
        expect(project.user).to eq(current_user)
      end

      it 'triggers outline generation' do
        # Mock the outline generation to avoid external dependencies
        allow_any_instance_of(Api::ProjectsController).to receive(:generate_outline_for_project)
        
        post '/api/projects', params: valid_project_params, headers: auth_headers
        
        expect(response).to have_http_status(:created)
      end

      it 'returns ISO 8601 formatted dates' do
        post '/api/projects', params: valid_project_params, headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        expect(response_data['createdAt']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end

    context 'with invalid parameters' do
      it 'does not create a project' do
        expect {
          post '/api/projects', params: invalid_project_params, headers: auth_headers
        }.not_to change(Project, :count)
        
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns structured error response' do
        post '/api/projects', params: invalid_project_params, headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        expect(response_data).to include('message', 'code', 'details')
        expect(response_data['code']).to eq('VALIDATION_ERROR')
        expect(response_data['details']).to have_key('field_errors')
      end
    end

    context 'with missing parameters' do
      it 'returns parameter missing error' do
        post '/api/projects', params: {}, headers: auth_headers
        
        expect(response).to have_http_status(:bad_request)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('MISSING_PARAMETER')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post '/api/projects', params: valid_project_params
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/projects/:id' do
    let(:project) { create(:project_with_outline, user: current_user) }

    context 'with valid project ID' do
      it 'returns the project with complete outline structure' do
        get "/api/projects/#{project.id}", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        
        expect(response_data).to include(
          'id', 'title', 'status', 'createdAt', 'lastModifiedAt', 'outline'
        )
        expect(response_data['id']).to eq(project.id)
      end

      it 'includes complete outline structure' do
        get "/api/projects/#{project.id}", headers: auth_headers
        
        response_data = JSON.parse(response.body)
        outline = response_data['outline']
        
        expect(outline).to include('status', 'chapters')
        expect(outline['chapters']).to be_an(Array)
        expect(outline['chapters'].length).to be > 0
        
        chapter = outline['chapters'].first
        expect(chapter).to include(
          'chapterId', 'title', 'order', 'omitted', 'sections'
        )
        
        if chapter['sections'].any?
          section = chapter['sections'].first
          expect(section).to include(
            'sectionId', 'title', 'order', 'omitted', 'questions'
          )
          
          if section['questions'].any?
            question = section['questions'].first
            expect(question).to include(
              'questionId', 'text', 'order'
            )
          end
        end
      end

      it 'returns ISO 8601 formatted dates' do
        get "/api/projects/#{project.id}", headers: auth_headers
        
        response_data = JSON.parse(response.body)
        
        expect(response_data['createdAt']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
        expect(response_data['lastModifiedAt']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end

    context 'with non-existent project ID' do
      it 'returns not found error' do
        get "/api/projects/999999", headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('NOT_FOUND')
      end
    end

    context 'with project belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project, user: other_user) }

      it 'returns not found error' do
        get "/api/projects/#{other_project.id}", headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
        
        response_data = JSON.parse(response.body)
        expect(response_data['code']).to eq('NOT_FOUND')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get "/api/projects/#{project.id}"
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/projects/:id/outline' do
    let(:project) { create(:project_with_outline, user: current_user) }
    let(:chapter) { project.chapters.first }
    let(:section) { chapter.sections.first }

    let(:valid_outline_params) do
      {
        updates: [
          {
            chapterId: chapter.id,
            omitted: true
          },
          {
            sectionId: section.id,
            omitted: false
          }
        ]
      }
    end

    context 'with valid outline updates' do
      it 'updates the outline successfully' do
        patch "/api/projects/#{project.id}/outline", 
              params: valid_outline_params, 
              headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data).to include('message', 'projectId', 'status')
        expect(response_data['projectId']).to eq(project.id)
      end

      it 'applies chapter omission updates' do
        patch "/api/projects/#{project.id}/outline", 
              params: valid_outline_params, 
              headers: auth_headers
        
        chapter.reload
        expect(chapter.omitted).to be true
      end

      it 'applies section omission updates' do
        patch "/api/projects/#{project.id}/outline", 
              params: valid_outline_params, 
              headers: auth_headers
        
        section.reload
        expect(section.omitted).to be false
      end

      it 'updates project status and timestamp' do
        original_modified_at = project.last_modified_at
        
        travel_to(1.hour.from_now) do
          patch "/api/projects/#{project.id}/outline", 
                params: valid_outline_params, 
                headers: auth_headers
        end
        
        project.reload
        expect(project.status).to eq('outline_updated')
        expect(project.last_modified_at).to be > original_modified_at
      end
    end

    context 'with empty updates array' do
      it 'succeeds without making changes' do
        patch "/api/projects/#{project.id}/outline", 
              params: { updates: [] }, 
              headers: auth_headers
        
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with non-existent chapter or section IDs' do
      let(:invalid_params) do
        {
          updates: [
            {
              chapterId: 999999,
              omitted: true
            }
          ]
        }
      end

      it 'handles non-existent IDs gracefully' do
        patch "/api/projects/#{project.id}/outline", 
              params: invalid_params, 
              headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        # Should not fail, just ignore non-existent items
      end
    end

    context 'with project belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_project) { create(:project_with_outline, user: other_user) }

      it 'returns not found error' do
        patch "/api/projects/#{other_project.id}/outline", 
              params: valid_outline_params, 
              headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        patch "/api/projects/#{project.id}/outline", 
              params: valid_outline_params
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/projects/:id/transcript' do
    let(:project) { create(:project, user: current_user, status: 'completed') }

    context 'when transcript is ready' do
      let!(:transcript) { create(:transcript, project: project, status: 'ready') }

      it 'returns the transcript' do
        get "/api/projects/#{project.id}/transcript", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data).to include(
          'id', 'projectId', 'status', 'lastUpdated', 'content'
        )
        expect(response_data['id']).to eq(transcript.id)
        expect(response_data['projectId']).to eq(project.id)
        expect(response_data['status']).to eq('ready')
        expect(response_data['content']).to be_an(Array)
      end

      it 'returns ISO 8601 formatted lastUpdated' do
        get "/api/projects/#{project.id}/transcript", headers: auth_headers
        
        response_data = JSON.parse(response.body)
        expect(response_data['lastUpdated']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end

      it 'returns properly structured content' do
        transcript.update!(content_json: [
          {
            type: "chapter",
            chapterId: 1,
            title: "Introduction",
            text: nil,
            audioSegmentId: nil
          },
          {
            type: "paragraph",
            chapterId: 1,
            sectionId: 1,
            questionId: 1,
            text: "This is sample content.",
            audioSegmentId: 1
          }
        ])

        get "/api/projects/#{project.id}/transcript", headers: auth_headers
        
        response_data = JSON.parse(response.body)
        content = response_data['content']
        
        expect(content.length).to eq(2)
        expect(content[0]['type']).to eq('chapter')
        expect(content[1]['type']).to eq('paragraph')
      end
    end

    context 'when transcript is not ready' do
      it 'returns processing status' do
        get "/api/projects/#{project.id}/transcript", headers: auth_headers
        
        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['projectId']).to eq(project.id)
        expect(response_data['status']).to eq('processing')
        expect(response_data['lastUpdated']).to be_nil
        expect(response_data['content']).to eq([])
      end
    end

    context 'with project in transcribing status' do
      before do
        project.update!(status: 'transcribing')
      end

      it 'returns processing status' do
        get "/api/projects/#{project.id}/transcript", headers: auth_headers
        
        response_data = JSON.parse(response.body)
        expect(response_data['status']).to eq('processing')
      end
    end

    context 'with non-existent project' do
      it 'returns not found error' do
        get "/api/projects/999999/transcript", headers: auth_headers
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get "/api/projects/#{project.id}/transcript"
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  private

  def auth_headers
    {
      'Authorization' => "Bearer #{jwt_token_for(current_user)}",
      'Content-Type' => 'application/json'
    }
  end

  def jwt_token_for(user)
    # Mock JWT token generation - in real app this would use JwtService
    "mock_jwt_token_for_user_#{user.id}"
  end
end