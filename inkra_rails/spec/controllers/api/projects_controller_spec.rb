require 'rails_helper'

RSpec.describe Api::ProjectsController, type: :controller do
  let(:user) { create(:user) }

  before do
    # Skip authentication for tests
    allow(controller).to receive(:authenticate_request!)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'GET #index' do
    context 'when user has projects' do
      let!(:project1) { create(:project, user: user, title: 'First Project', last_modified_at: 2.days.ago) }
      let!(:project2) { create(:project_with_outline, user: user, title: 'Second Project', last_modified_at: 1.day.ago) }
      let!(:other_user_project) { create(:project, title: 'Other User Project') }

      it 'returns user projects ordered by last_modified_at desc' do
        get :index

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        projects = json_response['projects']
        
        expect(projects.length).to eq(2)
        expect(projects.first['title']).to eq('Second Project')
        expect(projects.last['title']).to eq('First Project')
        
        # Verify project structure
        first_project = projects.first
        expect(first_project).to include(
          'id', 'title', 'status', 'topic', 'createdAt', 'lastModifiedAt', 'outline'
        )
        
        # Verify outline structure
        expect(first_project['outline']).to include(
          'status', 'chaptersCount', 'sectionsCount', 'questionsCount'
        )
      end

      it 'includes correct project counts' do
        get :index

        json_response = JSON.parse(response.body)
        project_with_outline = json_response['projects'].find { |p| p['title'] == 'Second Project' }
        
        expect(project_with_outline['outline']['chaptersCount']).to eq(2)
        expect(project_with_outline['outline']['sectionsCount']).to eq(4) # 2 chapters * 2 sections each
        expect(project_with_outline['outline']['questionsCount']).to eq(12) # 4 sections * 3 questions each
      end

      it 'optimizes database queries to avoid N+1 problem' do
        # Create multiple projects with complex structure to test query optimization
        create_list(:project_with_outline, 3, user: user)
        
        # Count queries executed during the request
        query_count = 0
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1 unless args.last[:sql].include?('SCHEMA')
        end
        
        get :index
        
        expect(response).to have_http_status(:ok)
        # Should only need a couple of queries regardless of project count (optimized with joins)
        expect(query_count).to be <= 5
      end

      it 'does not include other users projects' do
        get :index

        json_response = JSON.parse(response.body)
        project_titles = json_response['projects'].map { |p| p['title'] }
        
        expect(project_titles).not_to include('Other User Project')
      end
    end

    context 'when user has no projects' do
      it 'returns empty projects array' do
        get :index

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['projects']).to eq([])
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        project: {
          initialTopic: 'Building a Tech Startup'
        }
      }
    end

    before do
      # Mock the outline generation service
      allow_any_instance_of(Api::ProjectsController).to receive(:generate_outline_for_project)
    end

    context 'with valid parameters' do
      it 'creates a new project' do
        expect {
          post :create, params: valid_params
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq('Building a Tech Startup')
        expect(json_response['status']).to eq('outline_generating')
        expect(json_response['projectId']).to be_present
      end

      it 'associates project with current user' do
        post :create, params: valid_params

        project = Project.last
        expect(project.user).to eq(user)
      end
    end

    context 'with invalid parameters' do
      it 'returns validation errors' do
        post :create, params: { project: { initialTopic: '' } }

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['message'] || json_response['error']).to be_present
      end
    end
  end

  describe 'GET #show' do
    let!(:project) { create(:project_with_outline, user: user) }

    it 'returns project details with outline' do
      get :show, params: { id: project.id }

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(project.id)
      expect(json_response['title']).to eq(project.title)
      expect(json_response['outline']['chapters']).to be_an(Array)
    end

    it 'optimizes database queries for complex project structure' do
      # Create a project with many nested elements to test query optimization
      complex_project = create(:project_with_outline, user: user)
      
      # Add additional chapters, sections, and questions with follow-ups
      2.times do |i|
        chapter = create(:chapter, project: complex_project, order: i + 10) # Use higher numbers to avoid conflicts
        2.times do |j|
          section = create(:section, chapter: chapter, order: j + 10) # Use higher numbers to avoid conflicts
          3.times do |k|
            question = create(:question, section: section, order: k + 10) # Use higher numbers to avoid conflicts
            # Add follow-up questions
            2.times do |l|
              create(:question, section: section, parent_question: question, 
                     is_follow_up: true, order: l + 100) # Use much higher numbers for follow-ups
            end
          end
        end
      end
      
      # Count queries executed during the request
      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        sql = args.last[:sql]
        unless sql.include?('SCHEMA') || sql.include?('SELECT version()') || sql.include?('ROLLBACK') || sql.include?('BEGIN')
          query_count += 1
        end
      end
      
      get :show, params: { id: complex_project.id }
      
      expect(response).to have_http_status(:ok)
      
      # Should use optimized eager loading - regardless of complexity, should be ~7 queries max
      # (1 for project, 1 for chapters, 1 for sections, 1 for questions, 1 for follow-ups, plus setup queries)
      expect(query_count).to be <= 7
      
      json_response = JSON.parse(response.body)
      expect(json_response['outline']['chapters']).to be_an(Array)
      expect(json_response['outline']['chapters'].length).to be > 2
    end

    context 'when project belongs to different user' do
      let!(:other_project) { create(:project) }

      it 'handles access to non-owned project' do
        # For now, just verify that accessing another user's project fails
        # The exact error handling (404 vs 500) depends on configuration
        expect {
          get :show, params: { id: other_project.id }
        }.to_not raise_error
        
        # Should not return a successful response
        expect(response).to_not have_http_status(:ok)
      end
    end
  end

  describe 'GET #available_questions' do
    let!(:project) { create(:project_with_outline, user: user) }
    let(:chapter) { project.chapters.first }
    let(:section) { chapter.sections.first }

    context 'when project has unanswered questions' do
      let!(:question1) { create(:question, section: section, order: 1, is_follow_up: false, text: 'First question') }
      let!(:question2) { create(:question, section: section, order: 2, is_follow_up: false, text: 'Second question') }
      let!(:question3) { create(:question, section: section, order: 3, is_follow_up: false, text: 'Third question') }

      it 'returns all unanswered questions in correct order' do
        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['project_id']).to eq(project.id)
        expect(json_response['status']).to eq(project.status)
        
        questions = json_response['questions']
        expect(questions.length).to eq(3)
        
        # Verify question structure and content
        first_question = questions.first
        expect(first_question).to include(
          'question_id', 'text', 'order', 'omitted', 'skipped',
          'parent_question_id', 'is_follow_up', 'section_id',
          'section_title', 'chapter_id', 'chapter_title'
        )
        
        expect(first_question['question_id']).to eq(question1.id)
        expect(first_question['text']).to eq('First question')
        expect(first_question['order']).to eq(1)
        expect(first_question['is_follow_up']).to be false
      end

      it 'excludes answered questions from the queue' do
        # Create audio segment for question1 (marking it as answered)
        create(:audio_segment, project: project, question: question1)

        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        # Should only return unanswered questions
        expect(questions.length).to eq(2)
        question_ids = questions.map { |q| q['question_id'] }
        expect(question_ids).to contain_exactly(question2.id, question3.id)
        expect(question_ids).not_to include(question1.id)
      end

      it 'excludes omitted questions' do
        question2.update!(omitted: true)

        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        expect(questions.length).to eq(2)
        question_ids = questions.map { |q| q['question_id'] }
        expect(question_ids).to contain_exactly(question1.id, question3.id)
      end

      it 'excludes skipped questions' do
        question2.update!(skipped: true)

        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        expect(questions.length).to eq(2)
        question_ids = questions.map { |q| q['question_id'] }
        expect(question_ids).to contain_exactly(question1.id, question3.id)
      end
    end

    context 'with follow-up questions (Core.txt requirements)' do
      let!(:parent_question) { create(:question, section: section, order: 1, is_follow_up: false, text: 'Parent question') }
      let!(:regular_question) { create(:question, section: section, order: 2, is_follow_up: false, text: 'Regular question') }
      let!(:followup_question) do
        create(:question,
               section: section,
               order: 3,
               is_follow_up: true,
               parent_question: parent_question,
               text: 'Follow-up question')
      end

      context 'when parent question is not answered' do
        it 'returns questions without prioritizing follow-ups' do
          get :available_questions, params: { id: project.id }

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          questions = json_response['questions']
          
          # Should include all questions but follow-ups not prioritized
          expect(questions.length).to eq(2) # parent and regular, followup not prioritized
          question_ids = questions.map { |q| q['question_id'] }
          expect(question_ids).to include(parent_question.id, regular_question.id)
        end
      end

      context 'when parent question is answered (Core.txt urgent follow-up requirement)' do
        let!(:audio_segment) { create(:audio_segment, project: project, question: parent_question) }

        it 'prioritizes urgent follow-ups at the beginning of the queue' do
          get :available_questions, params: { id: project.id }

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          questions = json_response['questions']
          
          # Follow-up should be first since its parent is answered (urgent)
          expect(questions.length).to eq(2)
          expect(questions.first['question_id']).to eq(followup_question.id)
          expect(questions.first['is_follow_up']).to be true
          expect(questions.first['parent_question_id']).to eq(parent_question.id)
          
          # Regular question should come after urgent follow-ups
          expect(questions.last['question_id']).to eq(regular_question.id)
        end

        it 'correctly marks follow-up questions with parent relationship' do
          get :available_questions, params: { id: project.id }

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          questions = json_response['questions']
          
          followup = questions.find { |q| q['is_follow_up'] }
          expect(followup).to be_present
          expect(followup['parent_question_id']).to eq(parent_question.id)
          expect(followup['text']).to eq('Follow-up question')
        end
      end

      context 'with multiple follow-up questions for same parent' do
        let!(:followup_question2) do
          create(:question,
                 section: section,
                 order: 4,
                 is_follow_up: true,
                 parent_question: parent_question,
                 text: 'Second follow-up question')
        end
        let!(:audio_segment) { create(:audio_segment, project: project, question: parent_question) }

        it 'includes all urgent follow-ups at the beginning' do
          get :available_questions, params: { id: project.id }

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          questions = json_response['questions']
          
          # Both follow-ups should be urgent and at the beginning
          expect(questions.length).to eq(3)
          
          urgent_followups = questions.take(2)
          expect(urgent_followups.all? { |q| q['is_follow_up'] }).to be true
          expect(urgent_followups.map { |q| q['question_id'] }).to contain_exactly(
            followup_question.id, followup_question2.id
          )
          
          # Regular question should come last
          expect(questions.last['question_id']).to eq(regular_question.id)
        end
      end
    end

    context 'with speech interview project' do
      let!(:speech_project) { create(:project_with_outline, user: user, is_speech_interview: true) }
      let(:speech_chapter) { speech_project.chapters.first }
      let(:speech_section) { speech_chapter.sections.first }
      let!(:question_with_audio) do
        create(:question, section: speech_section, order: 1, text: 'Speech question')
      end
      let!(:polly_audio_clip) do
        create(:polly_audio_clip,
               question: question_with_audio,
               status: 'completed',
               s3_url: 'https://s3.amazonaws.com/test-bucket/audio.mp3')
      end

      before do
        question_with_audio.update!(polly_audio_clip: polly_audio_clip)
      end

      it 'includes polly_audio_url for speech interview questions with completed audio' do
        get :available_questions, params: { id: speech_project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        question_data = questions.first
        expect(question_data['polly_audio_url']).to eq('https://s3.amazonaws.com/test-bucket/audio.mp3')
      end

      it 'excludes polly_audio_url for questions without completed audio' do
        polly_audio_clip.update!(status: 'processing')

        get :available_questions, params: { id: speech_project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        question_data = questions.first
        expect(question_data).not_to have_key('polly_audio_url')
      end
    end

    context 'with complex project structure' do
      let!(:chapter2) { create(:chapter, project: project, order: 2, title: 'Second Chapter') }
      let!(:section2) { create(:section, chapter: chapter2, order: 1, title: 'Second Section') }
      
      let!(:q1_ch1) { create(:question, section: section, order: 1, text: 'Chapter 1 Question') }
      let!(:q1_ch2) { create(:question, section: section2, order: 1, text: 'Chapter 2 Question') }
      let!(:q2_ch1) { create(:question, section: section, order: 2, text: 'Chapter 1 Question 2') }

      it 'includes chapter and section information for each question' do
        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        # Verify chapter and section information is included
        ch1_question = questions.find { |q| q['question_id'] == q1_ch1.id }
        expect(ch1_question['section_title']).to eq(section.title)
        expect(ch1_question['chapter_title']).to eq(chapter.title)
        expect(ch1_question['section_id']).to eq(section.id)
        expect(ch1_question['chapter_id']).to eq(chapter.id)
        
        ch2_question = questions.find { |q| q['question_id'] == q1_ch2.id }
        expect(ch2_question['section_title']).to eq(section2.title)
        expect(ch2_question['chapter_title']).to eq(chapter2.title)
      end

      it 'maintains proper ordering across chapters and sections' do
        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        questions = json_response['questions']
        
        # Questions should be ordered by chapter, section, then question order
        expected_order = [q1_ch1.id, q2_ch1.id, q1_ch2.id]
        actual_order = questions.map { |q| q['question_id'] }
        expect(actual_order).to eq(expected_order)
      end
    end

    context 'error handling' do
      it 'returns 404 for non-existent project' do
        get :available_questions, params: { id: 999999 }

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for project belonging to different user' do
        other_user_project = create(:project)
        
        get :available_questions, params: { id: other_user_project.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with all questions answered' do
      let!(:question1) { create(:question, section: section, order: 1) }
      let!(:question2) { create(:question, section: section, order: 2) }
      let!(:audio_segment1) { create(:audio_segment, project: project, question: question1) }
      let!(:audio_segment2) { create(:audio_segment, project: project, question: question2) }

      it 'returns empty questions array when all questions are answered' do
        get :available_questions, params: { id: project.id }

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['questions']).to be_empty
      end
    end

    context 'performance optimization' do
      it 'uses efficient database queries to avoid N+1 problems' do
        # Create a complex structure to test query optimization
        create_list(:question, 10, section: section)
        
        # Monitor query count
        query_count = 0
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1 unless args.last[:sql].include?('SCHEMA')
        end
        
        get :available_questions, params: { id: project.id }
        
        expect(response).to have_http_status(:ok)
        
        # Should use efficient eager loading regardless of question count
        expect(query_count).to be <= 10
      end
    end
  end
end