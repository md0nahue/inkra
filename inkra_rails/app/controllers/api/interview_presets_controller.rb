class Api::InterviewPresetsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_request!
  before_action :set_interview_preset, only: [:show, :mark_as_shown, :launch]

  # GET /api/interview_presets
  def index
    # Get presets that haven't been shown to this user
    excluded_ids = @current_user.user_shown_interview_presets.pluck(:interview_preset_id)
    available_presets = InterviewPreset.active
                                     .where.not(id: excluded_ids)
                                     .ordered
                                     .limit(50)
    
    # If we have fewer than 2 available presets, reset the shown list and get fresh ones
    if available_presets.count < 2 && @current_user.user_shown_interview_presets.count > 0
      @current_user.user_shown_interview_presets.destroy_all
      available_presets = InterviewPreset.active.ordered.limit(50)
    end
    
    # Select 2 random presets for the home screen
    selected_presets = available_presets.order(Arel.sql('RANDOM()')).limit(2)
    
    render json: {
      presets: selected_presets.map do |preset|
        {
          uuid: preset.uuid,
          title: preset.title,
          description: preset.description,
          category: preset.category,
          icon_name: preset.icon_name,
          total_questions_count: preset.total_questions_count,
          is_featured: preset.is_featured
        }
      end
    }
  end

  # GET /api/interview_presets/:uuid
  def show
    render json: {
      preset: {
        uuid: @interview_preset.uuid,
        title: @interview_preset.title,
        description: @interview_preset.description,
        category: @interview_preset.category,
        icon_name: @interview_preset.icon_name,
        total_questions_count: @interview_preset.total_questions_count,
        is_featured: @interview_preset.is_featured,
        questions_by_chapter: @interview_preset.questions_grouped_by_chapter.transform_values do |questions|
          questions.map do |q|
            {
              id: q.id,
              text: q.question_text,
              chapter_title: q.chapter_title,
              section_title: q.section_title,
              order: [q.chapter_order, q.section_order, q.question_order]
            }
          end
        end
      }
    }
  end

  # POST /api/interview_presets/:uuid/mark_as_shown
  def mark_as_shown
    @interview_preset.mark_as_shown_to_user(@current_user)
    render json: { success: true }
  end

  # POST /api/interview_presets/:uuid/launch
  def launch
    # Mark as shown since user is engaging with it
    @interview_preset.mark_as_shown_to_user(@current_user)
    
    # Create a new project based on this preset
    project = @current_user.projects.build(
      title: @interview_preset.title,
      topic: @interview_preset.description,
      status: 'outline_ready',
      interview_preset_id: @interview_preset.id,
      is_speech_interview: true
    )
    
    if project.save
      # Create chapters, sections, and questions from the preset
      create_project_structure(project)
      
      render json: {
        success: true,
        project: {
          id: project.id,
          title: project.title,
          topic: project.topic,
          status: project.status
        }
      }
    else
      render json: {
        success: false,
        errors: project.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/interview_presets/categories
  def categories
    categories = InterviewPreset.active
                               .distinct
                               .pluck(:category)
                               .compact
                               .sort
    
    render json: { categories: categories }
  end

  # GET /api/interview_presets/featured
  def featured
    featured_presets = InterviewPreset.active.featured.ordered.limit(10)
    
    render json: {
      presets: featured_presets.map do |preset|
        {
          uuid: preset.uuid,
          title: preset.title,
          description: preset.description,
          category: preset.category,
          icon_name: preset.icon_name,
          total_questions_count: preset.total_questions_count,
          is_featured: preset.is_featured
        }
      end
    }
  end

  private

  def set_interview_preset
    @interview_preset = InterviewPreset.find_by!(uuid: params[:uuid])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Interview preset not found' }, status: :not_found
  end

  def create_project_structure(project)
    questions_by_chapter = @interview_preset.questions_grouped_by_chapter
    
    questions_by_chapter.each do |chapter_title, questions|
      chapter = project.chapters.create!(
        title: chapter_title,
        order: questions.first.chapter_order,
        omitted: false
      )
      
      # Group questions by section within this chapter
      questions_by_section = questions.group_by(&:section_title)
      
      questions_by_section.each do |section_title, section_questions|
        section = chapter.sections.create!(
          title: section_title,
          order: section_questions.first.section_order,
          omitted: false
        )
        
        # Create questions in this section
        section_questions.each do |preset_question|
          section.questions.create!(
            text: preset_question.question_text,
            order: preset_question.question_order,
            omitted: false,
            skipped: false
          )
        end
      end
    end
  end
end