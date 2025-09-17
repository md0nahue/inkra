class Project < ApplicationRecord
  belongs_to :user
  has_many :chapters, dependent: :destroy
  has_many :sections, through: :chapters
  has_many :questions, through: :sections
  has_many :audio_segments, dependent: :destroy
  has_one :transcript, dependent: :destroy
  has_many :advisor_interactions, dependent: :destroy

  validates :title, presence: true
  validates :topic, presence: true
  validates :is_speech_interview, inclusion: { in: [true, false] }
  
  enum status: { 
    outline_generating: 'outline_generating',
    outline_ready: 'outline_ready',
    recording_in_progress: 'recording_in_progress', 
    transcribing: 'transcribing',
    completed: 'completed',
    failed: 'failed'
  }

  before_create :set_timestamps
  before_update :update_last_modified
  before_destroy :cleanup_sidekiq_jobs

  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where.not(status: 'failed') }
  scope :templates, -> { where(is_template: true) }
  scope :user_projects, -> { where(is_template: false) }
  scope :recently_accessed, -> { where.not(last_accessed_at: nil).order(last_accessed_at: :desc) }
  
  def touch_accessed
    update_column(:last_accessed_at, Time.current)
  end

  def outline_status
    return 'generating' if status == 'outline_generating'
    return 'not_started' if chapters.empty?
    return 'ready' if chapters.any?
    'failed'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def can_record?
    # Always allow recording - no status-based locking
    true
  end

  def transcript_ready?
    transcript&.status == 'ready'
  end

  # Copy this template to create a new user project
  def create_instance_for_user(user, custom_title: nil, custom_topic: nil, custom_status: 'outline_ready')
    return nil unless is_template?

    new_project = user.projects.build(
      title: custom_title || title,
      topic: custom_topic || topic,
      status: custom_status,
      is_speech_interview: is_speech_interview,
      is_template: false,
      template_name: nil,
      template_description: nil
    )

    if new_project.save
      # Copy chapters, sections, and questions structure
      chapters.includes(sections: :questions).each do |chapter|
        new_chapter = new_project.chapters.create!(
          title: chapter.title,
          order: chapter.order,
          omitted: chapter.omitted
        )

        chapter.sections.each do |section|
          new_section = new_chapter.sections.create!(
            title: section.title,
            order: section.order,
            omitted: section.omitted
          )

          section.questions.each do |question|
            new_section.questions.create!(
              text: question.text,
              order: question.order,
              omitted: question.omitted,
              skipped: question.skipped,
              parent_question_id: question.parent_question_id,
              is_followup: question.is_followup
            )
          end
        end
      end
    end

    new_project
  end

  def template?
    is_template?
  end

  # Class method to get available templates
  def self.available_templates
    templates.order(:template_name, :title)
  end


  def has_audio_content?
    audio_segments.where.not(s3_url: nil).exists?
  end

  def has_transcript_content?
    transcript&.raw_structured_content.present? || transcript&.raw_content.present?
  end


  def has_meaningful_content?
    has_audio_content? || has_substantial_transcript_content?
  end

  def has_substantial_transcript_content?
    return false unless transcript&.raw_content.present?
    transcript.raw_content.length > 100
  end


  private

  def set_timestamps
    self.last_modified_at = Time.current
  end

  def update_last_modified
    self.last_modified_at = Time.current
  end

  def cleanup_sidekiq_jobs
    Rails.logger.info "Cleaning up Sidekiq jobs for project #{id}"
    
    # Find jobs related to this project's audio segments
    audio_segment_ids = audio_segments.pluck(:id)
    
    # Clean up jobs for project and related audio segments
    cleanup_jobs_by_args([
      [id.to_s],                    # FinalizeTranscriptJob
      audio_segment_ids.map(&:to_s) # TranscriptionJob, GenerateFollowupQuestionsJob
    ].flatten)
  end

  def cleanup_jobs_by_args(target_args)
    require 'sidekiq/api'
    
    # Clean up scheduled and retry queues
    [Sidekiq::ScheduledSet.new, Sidekiq::RetrySet.new, Sidekiq::Queue.new].each do |queue|
      queue.each do |job|
        if target_args.include?(job.args.first.to_s)
          Rails.logger.info "Removing Sidekiq job: #{job.klass} with args #{job.args}"
          job.delete
        end
      rescue => e
        Rails.logger.warn "Failed to delete Sidekiq job: #{e.message}"
      end
    end
  end
end
