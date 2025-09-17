require 'rails_helper'

RSpec.describe Api::ProjectsController, type: :controller do
  describe 'callback authentication patterns' do
    let(:user) { create(:user) }
    let(:project) { create(:project, user: user) }
    let(:token) { JwtService.encode_access_token(user.id) }
    
    before do
      request.headers['Authorization'] = "Bearer #{token}"
    end
    
    describe 'set_project callback' do
      context 'actions that should NOT require set_project' do
        it 'index action should work without project parameter' do
          get :index
          expect(response).to have_http_status(:ok)
        end
        
        it 'recent action should work without project parameter' do
          get :recent
          expect(response).to have_http_status(:ok)
        end
        
        it 'create action should work without project parameter' do
          post :create, params: { project: { title: 'Test', topic: 'Test Topic' } }
          expect(response).to have_http_status(:created)
        end
      end
      
      context 'actions that SHOULD require set_project' do
        let(:project_requiring_actions) do
          %i[
            show update destroy outline transcript add_more_chapters
            complete_interview available_questions questions_with_responses
            follow_up_questions generate_audiogram_data generate_stock_image_topics
            fetch_stock_images questions_diff update_share_settings
            share_url interview_mode
          ]
        end
        
        it 'should require project parameter for all project-specific actions' do
          project_requiring_actions.each do |action|
            expect do
              case action
              when :update
                patch action, params: { id: project.id, project: { title: 'Updated' } }
              when :destroy
                delete action, params: { id: project.id }
              when :interview_mode
                post action, params: { id: project.id, is_speech_interview: false }
              when :update_share_settings
                patch action, params: { id: project.id, share_settings: { enabled: true } }
              else
                get action, params: { id: project.id }
              end
            end.not_to raise_error
          end
        end
        
        it 'interview_mode action should work with valid project' do
          post :interview_mode, params: { id: project.id, is_speech_interview: false }
          expect(response).to have_http_status(:ok)
        end
        
        it 'should fail with 404 for non-existent project' do
          post :interview_mode, params: { id: 999999, is_speech_interview: false }
          expect(response).to have_http_status(:not_found)
        end
        
        it 'should fail with 404 for project belonging to different user' do
          other_user = create(:user)
          other_project = create(:project, user: other_user)
          
          post :interview_mode, params: { id: other_project.id, is_speech_interview: false }
          expect(response).to have_http_status(:not_found)
        end
      end
    end
    
    describe 'Rails 7.1 callback validation' do
      it 'should not raise callback validation errors during controller loading' do
        expect { Api::ProjectsController }.not_to raise_error
      end
      
      it 'should have interview_mode method defined and accessible' do
        expect(Api::ProjectsController.instance_methods).to include(:interview_mode)
      end
      
      it 'callback should be able to find interview_mode action' do
        controller = Api::ProjectsController.new
        expect(controller).to respond_to(:interview_mode)
      end
    end
    
    describe 'error handling improvements' do
      it 'should return proper error format for missing parameters' do
        post :interview_mode, params: { id: project.id }
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json).to have_key('message')
        expect(json).to have_key('code')
        expect(json['code']).to eq('MISSING_PARAMETER')
      end
      
      it 'should not mask 500 errors as 400 errors' do
        # This test ensures that server errors are properly reported
        allow_any_instance_of(Api::ProjectsController).to receive(:interview_mode).and_raise(StandardError, 'Test error')
        
        post :interview_mode, params: { id: project.id, is_speech_interview: false }
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end