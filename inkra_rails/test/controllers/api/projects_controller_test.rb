require "test_helper"

class Api::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @valid_attributes = {
      project: {
        initialTopic: "My life story"
      }
    }
    @invalid_attributes = {
      project: {
        initialTopic: ""
      }
    }
  end

  test "should create project with valid attributes" do
    assert_difference('Project.count') do
      post api_projects_url, params: @valid_attributes, as: :json
    end

    assert_response :created
    
    response_data = JSON.parse(response.body)
    assert_includes response_data, 'projectId'
    assert_includes response_data, 'title'
    assert_includes response_data, 'status'
    assert_includes response_data, 'createdAt'
    
    assert_equal "My life story", response_data['title']
    assert_equal "outline_generating", response_data['status']
    
    # Verify ISO 8601 date format
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, response_data['createdAt']
  end

  test "should not create project with invalid attributes" do
    assert_no_difference('Project.count') do
      post api_projects_url, params: @invalid_attributes, as: :json
    end

    assert_response :bad_request
    
    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "VALIDATION_ERROR", response_data['code']
  end

  test "should show project with complete outline structure" do
    # Create a project with full outline structure
    project = Project.create!(title: "Test Project", topic: "Test", status: "outline_ready")
    chapter = project.chapters.create!(title: "Chapter 1", order: 1, omitted: false)
    section = chapter.sections.create!(title: "Section 1", order: 1, omitted: false)
    question = section.questions.create!(text: "What is your name?", order: 1)

    get api_project_url(project), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    
    # Verify top-level structure
    assert_equal project.id, response_data['id']
    assert_equal project.title, response_data['title']
    assert_equal project.status, response_data['status']
    assert_includes response_data, 'createdAt'
    assert_includes response_data, 'lastModifiedAt'
    assert_includes response_data, 'outline'

    # Verify outline structure
    outline = response_data['outline']
    assert_includes outline, 'status'
    assert_includes outline, 'chapters'
    assert_equal 1, outline['chapters'].length

    # Verify chapter structure
    chapter_data = outline['chapters'].first
    assert_equal chapter.id, chapter_data['chapterId']
    assert_equal chapter.title, chapter_data['title']
    assert_equal chapter.order, chapter_data['order']
    assert_equal chapter.omitted, chapter_data['omitted']
    assert_includes chapter_data, 'sections'

    # Verify section structure
    section_data = chapter_data['sections'].first
    assert_equal section.id, section_data['sectionId']
    assert_equal section.title, section_data['title']
    assert_equal section.order, section_data['order']
    assert_equal section.omitted, section_data['omitted']
    assert_includes section_data, 'questions'

    # Verify question structure
    question_data = section_data['questions'].first
    assert_equal question.id, question_data['questionId']
    assert_equal question.text, question_data['text']
    assert_equal question.order, question_data['order']
  end

  test "should return 404 for non-existent project" do
    get api_project_url(99999), as: :json
    assert_response :not_found

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "NOT_FOUND", response_data['code']
  end

  test "should update outline with chapter omissions" do
    project = Project.create!(title: "Test Project", topic: "Test", status: "outline_ready")
    chapter = project.chapters.create!(title: "Chapter 1", order: 1, omitted: false)

    updates = {
      updates: [
        {
          chapterId: chapter.id,
          omitted: true
        }
      ]
    }

    patch outline_api_project_url(project), params: updates, as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'projectId'
    assert_includes response_data, 'status'

    # Verify chapter was updated
    chapter.reload
    assert chapter.omitted
  end

  test "should update outline with section omissions" do
    project = Project.create!(title: "Test Project", topic: "Test", status: "outline_ready")
    chapter = project.chapters.create!(title: "Chapter 1", order: 1, omitted: false)
    section = chapter.sections.create!(title: "Section 1", order: 1, omitted: false)

    updates = {
      updates: [
        {
          sectionId: section.id,
          omitted: true
        }
      ]
    }

    patch outline_api_project_url(project), params: updates, as: :json
    assert_response :success

    # Verify section was updated
    section.reload
    assert section.omitted
  end

  test "should return transcript when available" do
    project = Project.create!(title: "Test Project", topic: "Test", status: "completed")
    transcript = project.create_transcript!(
      status: "ready",
      content_json: [
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
          text: "This is a sample paragraph.",
          audioSegmentId: 1
        }
      ],
      last_updated: Time.current
    )

    get transcript_api_project_url(project), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_equal transcript.id, response_data['id']
    assert_equal project.id, response_data['projectId']
    assert_equal "ready", response_data['status']
    assert_includes response_data, 'lastUpdated'
    assert_includes response_data, 'content'
    assert_equal 2, response_data['content'].length
  end

  test "should return processing status when transcript not ready" do
    project = Project.create!(title: "Test Project", topic: "Test", status: "transcribing")

    get transcript_api_project_url(project), as: :json
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_equal project.id, response_data['projectId']
    assert_equal "processing", response_data['status']
    assert_nil response_data['lastUpdated']
    assert_equal [], response_data['content']
  end

  test "should handle missing required parameters" do
    post api_projects_url, params: {}, as: :json
    assert_response :bad_request

    response_data = JSON.parse(response.body)
    assert_includes response_data, 'message'
    assert_includes response_data, 'code'
    assert_equal "MISSING_PARAMETER", response_data['code']
  end
end