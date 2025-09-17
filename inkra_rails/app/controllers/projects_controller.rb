class ProjectsController < ApplicationController
  before_action :set_project, only: [:show]

  def index
    @projects = Project.order(created_at: :desc)
  end

  def show
    @chapters = @project.chapters.by_order.includes(:sections => :questions)
    @transcript = @project.transcript
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.status = 'outline_generating'
    
    if @project.save
      # Generate outline (same logic as API)
      generate_outline_for_project(@project)
      redirect_to @project, notice: 'Project was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :topic)
  end

  def generate_outline_for_project(project)
    # Same logic as in API controller
    chapters_data = [
      {
        title: 'Early Days: The Idea',
        order: 1,
        sections: [
          {
            title: 'The Spark of Innovation',
            order: 1,
            questions: [
              { text: 'What was the initial problem you aimed to solve?', order: 1 },
              { text: 'How did you first come up with this idea?', order: 2 }
            ]
          }
        ]
      },
      {
        title: 'Building the Foundation',
        order: 2,
        sections: [
          {
            title: 'First Steps',
            order: 1,
            questions: [
              { text: 'What were your first concrete actions?', order: 1 }
            ]
          }
        ]
      }
    ]
    
    chapters_data.each do |chapter_data|
      chapter = project.chapters.create!(
        title: chapter_data[:title],
        order: chapter_data[:order],
        omitted: false
      )
      
      chapter_data[:sections].each do |section_data|
        section = chapter.sections.create!(
          title: section_data[:title],
          order: section_data[:order],
          omitted: false
        )
        
        section_data[:questions].each do |question_data|
          section.questions.create!(
            text: question_data[:text],
            order: question_data[:order]
          )
        end
      end
    end
    
    project.update!(status: 'outline_ready')
  end
end
