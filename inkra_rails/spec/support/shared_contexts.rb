RSpec.shared_context "with authenticated user" do
  let(:current_user) { create(:user) }
  
  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_request!).and_return(true)
  end
end

RSpec.shared_context "with project setup" do
  include_context "with authenticated user"
  
  let(:project) { create(:project, user: current_user) }
  let(:chapter) { create(:chapter, project: project) }
  let(:section) { create(:section, chapter: chapter) }
  let(:question) { create(:question, section: section) }
end