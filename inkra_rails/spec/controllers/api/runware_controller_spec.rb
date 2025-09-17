# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::RunwareController, type: :controller do
  let(:user) { create(:user) }
  let(:runware_service) { instance_double(RunwareService) }

  before do
    allow(RunwareService).to receive(:new).and_return(runware_service)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'POST #create_icon' do
    let(:valid_params) { { prompt: 'a glowing nebula shaped like a cat', size: 1024 } }
    let(:successful_result) do
      {
        success: true,
        image_url: 'https://example.com/generated-icon.jpg',
        task_uuid: 'test-uuid-123',
        width: 1024,
        height: 1024
      }
    end

    context 'when authenticated' do
      context 'with valid parameters' do
        before do
          allow(runware_service).to receive(:create_icon).and_return(successful_result)
        end

        it 'returns successful response with image URL' do
          post :create_icon, params: valid_params

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['image_url']).to eq('https://example.com/generated-icon.jpg')
          expect(json_response['task_uuid']).to eq('test-uuid-123')
          expect(json_response['dimensions']).to eq('1024x1024')
        end

        it 'calls runware service with correct parameters' do
          post :create_icon, params: valid_params

          expect(runware_service).to have_received(:create_icon).with(prompt: 'a glowing nebula shaped like a cat', size: 1024)
        end
      end

      context 'with missing prompt' do
        it 'returns bad request error' do
          post :create_icon, params: { size: 1024 }

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Prompt is required')
        end
      end

      context 'when service returns error' do
        let(:error_result) { { success: false, error: 'Image size must be divisible by 64' } }

        before do
          allow(runware_service).to receive(:create_icon).and_return(error_result)
        end

        it 'returns unprocessable entity with error message' do
          post :create_icon, params: { prompt: 'test', size: 1000 }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
          expect(json_response['error']).to eq('Image size must be divisible by 64')
        end
      end
    end

    context 'when not authenticated' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it 'returns unauthorized error' do
        post :create_icon, params: valid_params

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Authentication required')
      end
    end
  end

  describe 'POST #create_portrait' do
    let(:valid_params) { { prompt: 'astronaut meditating in space', height: 1344 } }
    let(:successful_result) do
      {
        success: true,
        image_url: 'https://example.com/generated-portrait.jpg',
        task_uuid: 'test-uuid-456',
        width: 756,
        height: 1344
      }
    end

    context 'when authenticated' do
      before do
        allow(runware_service).to receive(:create_portrait_photo).and_return(successful_result)
      end

      it 'returns successful response for portrait creation' do
        post :create_portrait, params: valid_params

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['image_url']).to eq('https://example.com/generated-portrait.jpg')
        expect(json_response['dimensions']).to eq('756x1344')
      end

      it 'uses default height when not provided' do
        post :create_portrait, params: { prompt: 'test prompt' }

        expect(runware_service).to have_received(:create_portrait_photo).with(prompt: 'test prompt', height: 1344)
      end
    end
  end

  describe 'POST #create_tall' do
    let(:valid_params) { { prompt: 'cascading waterfall of stars', height: 1984 } }
    let(:successful_result) do
      {
        success: true,
        image_url: 'https://example.com/generated-tall.jpg',
        task_uuid: 'test-uuid-789',
        width: 640,
        height: 1984
      }
    end

    context 'when authenticated' do
      before do
        allow(runware_service).to receive(:create_tall_photo).and_return(successful_result)
      end

      it 'returns successful response for tall image creation' do
        post :create_tall, params: valid_params

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['image_url']).to eq('https://example.com/generated-tall.jpg')
        expect(json_response['dimensions']).to eq('640x1984')
      end
    end
  end

  describe 'POST #create_custom' do
    let(:valid_params) { { prompt: 'mystical library in space', width: 1024, height: 768 } }
    let(:successful_result) do
      {
        success: true,
        image_url: 'https://example.com/generated-custom.jpg',
        task_uuid: 'test-uuid-custom',
        width: 1024,
        height: 768
      }
    end

    context 'when authenticated' do
      context 'with valid parameters' do
        before do
          allow(runware_service).to receive(:create_custom_image).and_return(successful_result)
        end

        it 'returns successful response for custom image creation' do
          post :create_custom, params: valid_params

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['image_url']).to eq('https://example.com/generated-custom.jpg')
          expect(json_response['dimensions']).to eq('1024x768')
        end

        it 'passes custom model parameter when provided' do
          params_with_model = valid_params.merge(model: 'custom:model:123')
          post :create_custom, params: params_with_model

          expect(runware_service).to have_received(:create_custom_image).with(
            prompt: 'mystical library in space',
            width: 1024,
            height: 768,
            model: 'custom:model:123'
          )
        end
      end

      context 'with missing width or height' do
        it 'returns bad request for missing width' do
          post :create_custom, params: { prompt: 'test', height: 768 }

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Both width and height are required')
        end

        it 'returns bad request for missing height' do
          post :create_custom, params: { prompt: 'test', width: 1024 }

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Both width and height are required')
        end
      end
    end
  end

  describe 'GET #status' do
    context 'when authenticated' do
      context 'when Runware service is properly configured' do
        it 'returns successful status' do
          get :status

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['service_available']).to be true
          expect(json_response['message']).to eq('Runware service is configured and ready')
        end
      end

      context 'when Runware service is not configured' do
        before do
          allow(RunwareService).to receive(:new).and_raise(ArgumentError, 'RUNWARE_API_KEY environment variable not set.')
        end

        it 'returns service unavailable status' do
          get :status

          expect(response).to have_http_status(:service_unavailable)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
          expect(json_response['service_available']).to be false
          expect(json_response['error']).to eq('RUNWARE_API_KEY environment variable not set.')
        end
      end
    end

    context 'when not authenticated' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it 'returns unauthorized error' do
        get :status

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Authentication required')
      end
    end
  end
end