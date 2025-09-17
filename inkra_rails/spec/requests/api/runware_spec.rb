# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Runware', type: :request do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => jwt_token_for(user), 'Content-Type' => 'application/json' } }

  before do
    allow(ENV).to receive(:[]).with('RUNWARE_API_KEY').and_return('test-api-key')
  end

  describe 'POST /api/runware/create_icon' do
    let(:valid_params) { { prompt: 'a glowing nebula shaped like a cat', size: 1024 } }
    
    context 'with valid authentication and parameters' do
      before do
        # Mock the HTTP request to Runware API
        stub_request(:post, 'https://api.runware.ai/v1/')
          .to_return(
            status: 200,
            body: {
              data: [{
                taskUUID: 'test-uuid-123',
                imageURL: 'https://example.com/generated-icon.jpg'
              }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates an icon successfully' do
        post '/api/runware/create_icon', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['image_url']).to eq('https://example.com/generated-icon.jpg')
        expect(json_response['task_uuid']).to eq('test-uuid-123')
        expect(json_response['dimensions']).to eq('1024x1024')
      end

      it 'makes correct API request to Runware' do
        post '/api/runware/create_icon', params: valid_params.to_json, headers: headers

        expect(WebMock).to have_requested(:post, 'https://api.runware.ai/v1/')
          .with { |request|
            body = JSON.parse(request.body)
            expect(body.first['positivePrompt']).to include('a glowing nebula shaped like a cat')
            expect(body.first['positivePrompt']).to include('Cosmic Lofi aesthetic')
            expect(body.first['width']).to eq(1024)
            expect(body.first['height']).to eq(1024)
            true
          }
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error' do
        post '/api/runware/create_icon', params: valid_params.to_json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Authentication required')
      end
    end

    context 'with invalid parameters' do
      it 'returns bad request for missing prompt' do
        post '/api/runware/create_icon', params: { size: 1024 }.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Prompt is required')
      end
    end

    context 'when Runware API returns error' do
      before do
        stub_request(:post, 'https://api.runware.ai/v1/')
          .to_return(
            status: 400,
            body: 'Bad Request',
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns unprocessable entity with error' do
        post '/api/runware/create_icon', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('HTTP Error: 400')
      end
    end
  end

  describe 'POST /api/runware/create_portrait' do
    let(:valid_params) { { prompt: 'astronaut meditating in space' } }

    context 'with valid parameters' do
      before do
        stub_request(:post, 'https://api.runware.ai/v1/')
          .to_return(
            status: 200,
            body: {
              data: [{
                taskUUID: 'test-uuid-456',
                imageURL: 'https://example.com/generated-portrait.jpg'
              }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'creates a portrait successfully' do
        post '/api/runware/create_portrait', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['image_url']).to eq('https://example.com/generated-portrait.jpg')
      end

      it 'uses 9:16 aspect ratio' do
        post '/api/runware/create_portrait', params: valid_params.to_json, headers: headers

        expect(WebMock).to have_requested(:post, 'https://api.runware.ai/v1/')
          .with { |request|
            body = JSON.parse(request.body)
            width = body.first['width']
            height = body.first['height']
            aspect_ratio = width.to_f / height.to_f
            expect(aspect_ratio).to be_within(0.01).of(9.0 / 16.0)
            true
          }
      end
    end
  end

  describe 'POST /api/runware/create_tall' do
    let(:valid_params) { { prompt: 'cascading waterfall of stars' } }

    before do
      stub_request(:post, 'https://api.runware.ai/v1/')
        .to_return(
          status: 200,
          body: {
            data: [{
              taskUUID: 'test-uuid-789',
              imageURL: 'https://example.com/generated-tall.jpg'
            }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'creates a tall image successfully' do
      post '/api/runware/create_tall', params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['image_url']).to eq('https://example.com/generated-tall.jpg')
    end

    it 'uses 6:19 aspect ratio' do
      post '/api/runware/create_tall', params: valid_params.to_json, headers: headers

      expect(WebMock).to have_requested(:post, 'https://api.runware.ai/v1/')
        .with { |request|
          body = JSON.parse(request.body)
          width = body.first['width']
          height = body.first['height']
          aspect_ratio = width.to_f / height.to_f
          expect(aspect_ratio).to be_within(0.01).of(6.0 / 19.0)
          true
        }
    end
  end

  describe 'POST /api/runware/create_custom' do
    let(:valid_params) { { prompt: 'mystical library in space', width: 1024, height: 768 } }

    before do
      stub_request(:post, 'https://api.runware.ai/v1/')
        .to_return(
          status: 200,
          body: {
            data: [{
              taskUUID: 'test-uuid-custom',
              imageURL: 'https://example.com/generated-custom.jpg'
            }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'creates a custom image successfully' do
      post '/api/runware/create_custom', params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['image_url']).to eq('https://example.com/generated-custom.jpg')
      expect(json_response['dimensions']).to eq('1024x768')
    end

    it 'returns bad request when width or height is missing' do
      post '/api/runware/create_custom', params: { prompt: 'test' }.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Both width and height are required')
    end
  end

  describe 'GET /api/runware/status' do
    context 'when service is available' do
      it 'returns successful status' do
        get '/api/runware/status', headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['service_available']).to be true
        expect(json_response['message']).to eq('Runware service is configured and ready')
      end
    end

    context 'when service is not configured' do
      before do
        allow(ENV).to receive(:[]).with('RUNWARE_API_KEY').and_return(nil)
      end

      it 'returns service unavailable status' do
        get '/api/runware/status', headers: headers

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['service_available']).to be false
      end
    end
  end

  private

  def jwt_token_for(user)
    # This assumes you have a JWT service similar to your existing auth setup
    # Adjust based on your actual JWT implementation
    payload = {
      user_id: user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end