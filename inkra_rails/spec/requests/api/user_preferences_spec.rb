require 'rails_helper'

RSpec.describe "Api::UserPreferences", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/api/user_preferences/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/user_preferences/update"
      expect(response).to have_http_status(:success)
    end
  end

end
