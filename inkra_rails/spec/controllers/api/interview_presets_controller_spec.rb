require 'rails_helper'

RSpec.describe Api::InterviewPresetsController, type: :controller do
  let(:user) { create(:user) }
  let(:preset1) { create(:interview_preset, title: 'First Preset') }
  let(:preset2) { create(:interview_preset, title: 'Second Preset') }
  let(:preset3) { create(:interview_preset, title: 'Third Preset') }

  before do
    # Mock authentication
    allow(controller).to receive(:authenticate_request!).and_return(true)
    controller.instance_variable_set(:@current_user, user)
  end

  describe 'GET #index' do
    context 'when user has no shown presets' do
      it 'returns 2 random active presets' do
        preset1 && preset2 && preset3 # Ensure presets exist
        
        get :index
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['presets'].size).to eq(2)
        
        returned_uuids = json_response['presets'].map { |p| p['uuid'] }
        all_uuids = [preset1.uuid, preset2.uuid, preset3.uuid]
        expect(returned_uuids).to all(be_in(all_uuids))
      end

      it 'excludes inactive presets' do
        active_preset = create(:interview_preset, active: true)
        inactive_preset = create(:interview_preset, active: false)
        
        get :index
        
        json_response = JSON.parse(response.body)
        returned_uuids = json_response['presets'].map { |p| p['uuid'] }
        
        expect(returned_uuids).to include(active_preset.uuid)
        expect(returned_uuids).not_to include(inactive_preset.uuid)
      end
    end

    context 'when user has seen some presets' do
      before do
        create(:user_shown_interview_preset, user: user, interview_preset: preset1)
      end

      it 'excludes already shown presets' do
        preset2 && preset3 # Ensure other presets exist
        
        get :index
        
        json_response = JSON.parse(response.body)
        returned_uuids = json_response['presets'].map { |p| p['uuid'] }
        
        expect(returned_uuids).not_to include(preset1.uuid)
        expect(returned_uuids.size).to eq(2)
      end
    end

    context 'when user has seen all presets' do
      before do
        [preset1, preset2, preset3].each do |preset|
          create(:user_shown_interview_preset, user: user, interview_preset: preset)
        end
      end

      it 'resets shown presets and returns fresh ones' do
        get :index
        
        expect(user.user_shown_interview_presets.count).to eq(0)
        
        json_response = JSON.parse(response.body)
        expect(json_response['presets'].size).to eq(2)
      end
    end

    it 'returns preset data in correct format' do
      preset = create(:interview_preset, 
                     title: 'Test Preset',
                     description: 'Test description',
                     category: 'creativity',
                     icon_name: 'lightbulb.fill',
                     is_featured: true)
      create_list(:preset_question, 5, interview_preset: preset)
      
      get :index
      
      json_response = JSON.parse(response.body)
      preset_data = json_response['presets'].first
      
      expect(preset_data).to include(
        'uuid' => preset.uuid,
        'title' => 'Test Preset',
        'description' => 'Test description',
        'category' => 'creativity',
        'icon_name' => 'lightbulb.fill',
        'total_questions_count' => 5,
        'is_featured' => true
      )
    end
  end

  describe 'GET #show' do
    let!(:preset) { create(:interview_preset) }
    let!(:question1) { create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', question_order: 1) }
    let!(:question2) { create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', question_order: 2) }
    let!(:question3) { create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 2', question_order: 1) }

    it 'returns preset with grouped questions' do
      get :show, params: { uuid: preset.uuid }
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['preset']['uuid']).to eq(preset.uuid)
      expect(json_response['preset']['questions_by_chapter'].keys).to contain_exactly('Chapter 1', 'Chapter 2')
      expect(json_response['preset']['questions_by_chapter']['Chapter 1'].size).to eq(2)
      expect(json_response['preset']['questions_by_chapter']['Chapter 2'].size).to eq(1)
    end

    it 'returns 404 for non-existent preset' do
      get :show, params: { uuid: 'non-existent-uuid' }
      
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #mark_as_shown' do
    let!(:preset) { create(:interview_preset) }

    it 'marks preset as shown for current user' do
      expect {
        post :mark_as_shown, params: { uuid: preset.uuid }
      }.to change(UserShownInterviewPreset, :count).by(1)
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      
      expect(preset.shown_to_user?(user)).to be true
    end

    it 'does not create duplicate records' do
      preset.mark_as_shown_to_user(user)
      
      expect {
        post :mark_as_shown, params: { uuid: preset.uuid }
      }.not_to change(UserShownInterviewPreset, :count)
    end
  end

  describe 'POST #launch' do
    let!(:preset) { create(:interview_preset, title: 'Launch Test', description: 'Test preset') }
    let!(:question1) { create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', section_title: 'Section 1', question_text: 'Question 1') }
    let!(:question2) { create(:preset_question, interview_preset: preset, chapter_title: 'Chapter 1', section_title: 'Section 1', question_text: 'Question 2') }

    it 'creates new project with preset structure' do
      expect {
        post :launch, params: { uuid: preset.uuid }
      }.to change(user.projects, :count).by(1)
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      
      project = user.projects.last
      expect(project.title).to eq('Launch Test')
      expect(project.topic).to eq('Test preset')
      expect(project.interview_preset_id).to eq(preset.id)
      expect(project.is_speech_interview).to be true
    end

    it 'creates project structure from preset questions' do
      post :launch, params: { uuid: preset.uuid }
      
      project = user.projects.last
      expect(project.chapters.count).to eq(1)
      
      chapter = project.chapters.first
      expect(chapter.title).to eq('Chapter 1')
      expect(chapter.sections.count).to eq(1)
      
      section = chapter.sections.first
      expect(section.title).to eq('Section 1')
      expect(section.questions.count).to eq(2)
      
      questions = section.questions.by_order
      expect(questions.map(&:text)).to eq(['Question 1', 'Question 2'])
    end

    it 'marks preset as shown to user' do
      post :launch, params: { uuid: preset.uuid }
      
      expect(preset.shown_to_user?(user)).to be true
    end

    it 'returns error for invalid preset' do
      post :launch, params: { uuid: 'invalid-uuid' }
      
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #categories' do
    it 'returns unique categories from active presets' do
      create(:interview_preset, category: 'creativity', active: true)
      create(:interview_preset, category: 'leadership', active: true)
      create(:interview_preset, category: 'creativity', active: true) # Duplicate
      create(:interview_preset, category: 'mindset', active: false) # Inactive
      
      get :categories
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['categories']).to contain_exactly('creativity', 'leadership')
    end
  end

  describe 'GET #featured' do
    it 'returns only featured active presets' do
      featured_preset = create(:interview_preset, is_featured: true, active: true)
      regular_preset = create(:interview_preset, is_featured: false, active: true)
      inactive_featured = create(:interview_preset, is_featured: true, active: false)
      
      get :featured
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      returned_uuids = json_response['presets'].map { |p| p['uuid'] }
      expect(returned_uuids).to include(featured_preset.uuid)
      expect(returned_uuids).not_to include(regular_preset.uuid)
      expect(returned_uuids).not_to include(inactive_featured.uuid)
    end
  end
end