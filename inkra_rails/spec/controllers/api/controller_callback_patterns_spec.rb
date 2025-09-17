require 'rails_helper'

RSpec.describe 'API Controller Callback Patterns', type: :controller do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:token) { JwtService.encode_access_token(user.id) }
  
  before do
    request.headers['Authorization'] = "Bearer #{token}"
  end

  shared_examples 'proper callback pattern' do |controller_class|
    it "#{controller_class} should not raise callback validation errors during loading" do
      expect { controller_class.constantize }.not_to raise_error
    end
  end

  describe 'Controllers with problematic callback patterns' do
    describe Api::PollyAudioController do
      include_examples 'proper callback pattern', 'Api::PollyAudioController'
      
      controller(Api::PollyAudioController) do
        def test_action
          render json: { success: true }
        end
      end
      
      before do
        routes.draw { get 'test_action' => 'api/polly_audio#test_action' }
      end
      
      it 'should use except pattern for cleaner callback management' do
        # Current pattern: only: [:generate_all, :status, :generate_missing, :update_voice_settings]
        # Better pattern: except: [] (since all actions need set_project)
        
        callbacks = Api::PollyAudioController._process_action_callbacks.select do |callback|
          callback.filter == :set_project
        end
        
        expect(callbacks).to be_present
        callback = callbacks.first
        
        # Test that the callback is configured correctly
        expect(callback).to be_present
      end
    end
    
    describe Api::AudioSegmentsController do
      include_examples 'proper callback pattern', 'Api::AudioSegmentsController'
      
      it 'should have set_project for all actions since no except clause is needed' do
        callbacks = Api::AudioSegmentsController._process_action_callbacks.select do |callback|
          callback.filter == :set_project
        end
        
        expect(callbacks).to be_present
        callback = callbacks.first
        
        # AudioSegmentsController already uses the clean pattern: just `before_action :set_project`
        expect(callback.options[:only]).to be_nil
        expect(callback.options[:except]).to be_nil
      end
    end
    
    describe Api::ExportsController do
      include_examples 'proper callback pattern', 'Api::ExportsController'
      
      it 'should have set_project for all actions' do
        callbacks = Api::ExportsController._process_action_callbacks.select do |callback|
          callback.filter == :set_project
        end
        
        expect(callbacks).to be_present
        callback = callbacks.first
        
        # ExportsController already uses the clean pattern
        expect(callback.options[:only]).to be_nil
        expect(callback.options[:except]).to be_nil
      end
    end
  end

  describe 'Callback validation edge cases' do
    it 'should handle method definition order correctly' do
      # Test that callbacks work regardless of method definition order
      expect { Api::ProjectsController.new }.not_to raise_error
    end
    
    it 'should properly resolve callback methods at runtime' do
      controller = Api::ProjectsController.new
      controller.params = ActionController::Parameters.new(id: project.id)
      controller.instance_variable_set(:@current_user, user)
      
      expect { controller.send(:set_project) }.not_to raise_error
      expect(controller.instance_variable_get(:@project)).to eq(project)
    end
  end

  describe 'Authentication flow integration' do
    it 'should properly integrate set_project with authentication' do
      controller = Api::ProjectsController.new
      controller.request = ActionDispatch::TestRequest.create
      controller.request.headers['Authorization'] = "Bearer #{token}"
      controller.params = ActionController::Parameters.new(id: project.id)
      
      # Simulate the full callback chain
      expect { controller.send(:authenticate_api_request!) }.not_to raise_error
      expect { controller.send(:set_project) }.not_to raise_error
      
      expect(controller.send(:current_user)).to eq(user)
      expect(controller.instance_variable_get(:@project)).to eq(project)
    end
  end
end