require 'rails_helper'

RSpec.describe Api::UserLifecycleController, type: :controller do
  let(:user) { create(:user) }
  let(:valid_headers) do
    # Assuming you have authentication headers
    { 'Authorization' => "Bearer #{generate_auth_token(user)}" }
  end

  before do
    # Mock current_user
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'POST #export_user_data' do
    it 'starts data export with default email' do
      expect(DataExportJob).to receive(:perform_later).with(user.id, user.email)

      post :export_user_data, params: {}

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to include('Data export started')
      expect(json['email']).to eq(user.email)
    end

    it 'starts data export with custom email' do
      custom_email = 'custom@example.com'
      expect(DataExportJob).to receive(:perform_later).with(user.id, custom_email)

      post :export_user_data, params: { email: custom_email }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['email']).to eq(custom_email)
    end

    it 'returns error when email is blank' do
      allow(user).to receive(:email).and_return(nil)

      post :export_user_data, params: { email: '' }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Email address is required')
    end
  end

  describe 'POST #delete_account' do
    let(:valid_params) do
      {
        experience_description: 'This is my experience with the app, it was okay but had some issues.',
        what_would_change: 'Better user interface',
        request_export: false
      }
    end

    it 'schedules account deletion without export' do
      expect(AccountDeletionJob).to receive(:perform_later).with(user.id, anything)

      post :delete_account, params: valid_params

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['deletion_scheduled']).to be true
      expect(json['export_requested']).to be false
    end

    it 'schedules account deletion with export' do
      params_with_export = valid_params.merge(request_export: true)
      
      expect(DataExportJob).to receive(:perform_later).with(user.id, user.email)
      expect(AccountDeletionJob).to receive(:set).with(wait: 30.minutes).and_return(double(perform_later: true))

      post :delete_account, params: params_with_export

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['deletion_scheduled']).to be true
      expect(json['export_requested']).to be true
      expect(json['message']).to include('30 minutes')
    end

    it 'returns error for insufficient feedback' do
      invalid_params = valid_params.merge(experience_description: 'Too short')

      post :delete_account, params: invalid_params

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('minimum 10 characters')
    end

    it 'saves deletion feedback to file' do
      expect(File).to receive(:open).with(anything, 'w')

      post :delete_account, params: valid_params

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #export_status' do
    it 'returns export status information' do
      get :export_status

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['user_id']).to eq(user.id)
      expect(json['email']).to eq(user.email)
    end
  end

  private

  def generate_auth_token(user)
    # Mock token generation - adjust based on your auth system
    "mock_token_for_user_#{user.id}"
  end
end