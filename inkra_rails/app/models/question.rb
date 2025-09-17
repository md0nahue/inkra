class Question < ApplicationRecord
  belongs_to :section
  has_many :audio_segments, dependent: :destroy
  has_one :polly_audio_clip, dependent: :destroy

  # Add these new associations
  belongs_to :parent_question, class_name: 'Question', optional: true
  has_many :follow_up_questions, class_name: 'Question', foreign_key: 'parent_question_id', dependent: :destroy

  validates :text, presence: true
  validates :order, presence: true, uniqueness: { scope: [:section_id, :parent_question_id] }
  validates :omitted, inclusion: { in: [true, false] }
  validates :skipped, inclusion: { in: [true, false] }

  before_destroy :cleanup_sidekiq_jobs

  scope :by_order, -> { order(:order) }
  scope :base_questions, -> { where(is_follow_up: false) }
  scope :included, -> { where(omitted: false) }
  scope :not_skipped, -> { where(skipped: false) }

  def is_follow_up?
    is_follow_up
  end

  def project
    section.chapter.project
  end

  # Check if this question is ready to be shown in a speech interview
  # For reading interviews, questions are always ready
  # For speech interviews, ALL questions need completed audio
  def audio_ready_for_speech_interview?
    # ALL questions in speech interviews need completed audio
    polly_audio_clip&.completed? == true
  end

  # Check if this question should be included in the available questions API
  # for a given project type (speech vs reading interview)
  def available_for_project_type?(is_speech_interview)
    # For reading interviews, all non-omitted, non-skipped questions are available
    return true unless is_speech_interview
    
    # For speech interviews, questions must have audio ready
    audio_ready_for_speech_interview?
  end

  private

  def cleanup_sidekiq_jobs
    Rails.logger.info "Cleaning up Sidekiq jobs for question #{id}"
    
    require 'sidekiq/api'
    
    # Clean up PollyGenerationJob for this question
    [Sidekiq::ScheduledSet.new, Sidekiq::RetrySet.new, Sidekiq::Queue.new].each do |queue|
      queue.each do |job|
        if job.klass == 'PollyGenerationJob' && job.args.first.to_s == id.to_s
          Rails.logger.info "Removing PollyGenerationJob for question #{id}"
          job.delete
        end
      rescue => e
        Rails.logger.warn "Failed to delete Sidekiq job for question #{id}: #{e.message}"
      end
    end
  end
end
