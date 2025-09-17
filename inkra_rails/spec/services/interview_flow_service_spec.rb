require 'rails_helper'

RSpec.describe InterviewFlowService, type: :service do
  let(:user) { create(:user) }
  let(:project) { create(:project_with_outline, user: user) }
  let(:chapter) { project.chapters.first }
  let(:section) { chapter.sections.first }
  let(:service) { InterviewFlowService.new(project) }

  describe '#generate_question_queue' do
    context 'with basic project structure' do
      let!(:question1) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:question2) { create(:question, section: section, order: 2, is_follow_up: false) }
      let!(:question3) { create(:question, section: section, order: 3, is_follow_up: false) }

      it 'returns all unanswered questions in correct order' do
        queue = service.generate_question_queue
        
        expect(queue.length).to eq(3)
        expect(queue.map(&:id)).to eq([question1.id, question2.id, question3.id])
      end

      it 'excludes omitted questions' do
        question2.update!(omitted: true)
        
        queue = service.generate_question_queue
        
        expect(queue.length).to eq(2)
        expect(queue.map(&:id)).to eq([question1.id, question3.id])
      end

      it 'excludes skipped questions' do
        question2.update!(skipped: true)
        
        queue = service.generate_question_queue
        
        expect(queue.length).to eq(2)
        expect(queue.map(&:id)).to eq([question1.id, question3.id])
      end

      it 'excludes questions from omitted sections' do
        section.update!(omitted: true)
        
        queue = service.generate_question_queue
        
        expect(queue).to be_empty
      end

      it 'excludes questions from omitted chapters' do
        chapter.update!(omitted: true)
        
        queue = service.generate_question_queue
        
        expect(queue).to be_empty
      end
    end

    context 'with answered questions' do
      let!(:question1) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:question2) { create(:question, section: section, order: 2, is_follow_up: false) }
      let!(:question3) { create(:question, section: section, order: 3, is_follow_up: false) }
      let!(:audio_segment) { create(:audio_segment, project: project, question: question1) }

      it 'excludes answered questions from queue' do
        queue = service.generate_question_queue
        
        expect(queue.length).to eq(2)
        expect(queue.map(&:id)).to eq([question2.id, question3.id])
      end

      it 'includes questions without audio segments' do
        queue = service.generate_question_queue
        
        unanswered_question_ids = queue.map(&:id)
        expect(unanswered_question_ids).to include(question2.id, question3.id)
        expect(unanswered_question_ids).not_to include(question1.id)
      end
    end

    context 'with follow-up questions' do
      let!(:parent_question) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:regular_question) { create(:question, section: section, order: 2, is_follow_up: false) }
      let!(:followup_question) do
        create(:question, 
               section: section, 
               order: 3, 
               is_follow_up: true, 
               parent_question: parent_question)
      end

      context 'when parent question is not answered' do
        it 'includes regular questions but not follow-ups without answered parents' do
          queue = service.generate_question_queue
          
          # Follow-ups without answered parents should not be prioritized
          # but still included in standard queue
          expect(queue.map(&:id)).to eq([parent_question.id, regular_question.id])
        end
      end

      context 'when parent question is answered (Core.txt requirement)' do
        let!(:audio_segment) { create(:audio_segment, project: project, question: parent_question) }

        it 'prioritizes urgent follow-ups at the front of queue' do
          queue = service.generate_question_queue
          
          # Urgent follow-ups (parent answered) should come first
          expect(queue.first.id).to eq(followup_question.id)
          expect(queue.map(&:id)).to eq([followup_question.id, regular_question.id])
        end

        it 'correctly identifies urgent follow-ups' do
          queue = service.generate_question_queue
          
          # The follow-up should be at the beginning since its parent is answered
          urgent_followup = queue.first
          expect(urgent_followup.is_follow_up).to be true
          expect(urgent_followup.parent_question_id).to eq(parent_question.id)
        end
      end

      context 'with multiple follow-up levels' do
        let!(:second_level_followup) do
          create(:question,
                 section: section,
                 order: 4,
                 is_follow_up: true,
                 parent_question: followup_question)
        end
        let!(:audio_segment1) { create(:audio_segment, project: project, question: parent_question) }
        let!(:audio_segment2) { create(:audio_segment, project: project, question: followup_question) }

        it 'handles nested follow-up questions correctly' do
          queue = service.generate_question_queue
          
          # Both follow-ups should be urgent since their parents are answered
          urgent_question_ids = queue.select(&:is_follow_up).map(&:id)
          expect(urgent_question_ids).to include(second_level_followup.id)
        end
      end
    end

    context 'with complex project structure' do
      let!(:chapter2) { create(:chapter, project: project, order: 2) }
      let!(:section2) { create(:section, chapter: chapter2, order: 1) }
      
      let!(:q1_ch1_s1) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:q2_ch1_s1) { create(:question, section: section, order: 2, is_follow_up: false) }
      let!(:q1_ch2_s1) { create(:question, section: section2, order: 1, is_follow_up: false) }
      
      let!(:followup_q1) do
        create(:question,
               section: section,
               order: 3,
               is_follow_up: true,
               parent_question: q1_ch1_s1)
      end
      
      let!(:audio_segment) { create(:audio_segment, project: project, question: q1_ch1_s1) }

      it 'maintains proper ordering across chapters and sections' do
        queue = service.generate_question_queue
        
        # Urgent follow-up should be first, then remaining questions in order
        expect(queue.first.id).to eq(followup_q1.id)
        
        # Remaining questions should follow chapter/section/question order
        remaining_questions = queue.drop(1)
        expect(remaining_questions.map(&:id)).to eq([q2_ch1_s1.id, q1_ch2_s1.id])
      end

      it 'correctly orders questions across multiple chapters' do
        # Remove the answered question to test pure ordering
        audio_segment.destroy
        
        queue = service.generate_question_queue
        
        # Should be ordered by chapter, then section, then question order
        expected_order = [q1_ch1_s1.id, q2_ch1_s1.id, q1_ch2_s1.id]
        expect(queue.map(&:id)).to eq(expected_order)
      end
    end
  end

  describe '#insert_followup_questions' do
    let!(:question1) { create(:question, section: section, order: 1) }
    let!(:question2) { create(:question, section: section, order: 2) }
    let!(:question3) { create(:question, section: section, order: 3) }
    let(:current_queue) { [question1, question2, question3] }

    context 'inserting follow-ups after parent question' do
      let!(:new_followup1) do
        create(:question,
               section: section,
               order: 4,
               is_follow_up: true,
               parent_question: question1)
      end
      let!(:new_followup2) do
        create(:question,
               section: section,
               order: 5,
               is_follow_up: true,
               parent_question: question1)
      end
      let(:new_followups) { [new_followup1, new_followup2] }

      it 'inserts follow-ups immediately after parent question' do
        result_queue = service.insert_followup_questions(current_queue, question1.id, new_followups)
        
        expected_order = [question1.id, new_followup1.id, new_followup2.id, question2.id, question3.id]
        expect(result_queue.map(&:id)).to eq(expected_order)
      end

      it 'returns original queue when parent not found' do
        result_queue = service.insert_followup_questions(current_queue, 999999, new_followups)
        
        expect(result_queue.map(&:id)).to eq([question1.id, question2.id, question3.id])
      end

      it 'returns original queue when no new follow-ups provided' do
        result_queue = service.insert_followup_questions(current_queue, question1.id, [])
        
        expect(result_queue.map(&:id)).to eq([question1.id, question2.id, question3.id])
      end
    end

    context 'with existing follow-ups' do
      let!(:existing_followup) do
        create(:question,
               section: section,
               order: 4,
               is_follow_up: true,
               parent_question: question1)
      end
      let!(:new_followup) do
        create(:question,
               section: section,
               order: 5,
               is_follow_up: true,
               parent_question: question1)
      end
      let(:queue_with_existing) { [question1, existing_followup, question2, question3] }

      it 'inserts new follow-ups after existing ones' do
        result_queue = service.insert_followup_questions(queue_with_existing, question1.id, [new_followup])
        
        expected_order = [question1.id, existing_followup.id, new_followup.id, question2.id, question3.id]
        expect(result_queue.map(&:id)).to eq(expected_order)
      end
    end
  end

  describe '#get_next_priority_question' do
    let!(:question1) { create(:question, section: section, order: 1) }
    let!(:question2) { create(:question, section: section, order: 2) }
    let!(:question3) { create(:question, section: section, order: 3) }
    let(:queue) { [question1, question2, question3] }

    it 'returns next question in sequence' do
      next_question = service.get_next_priority_question(queue, 0)
      
      expect(next_question.id).to eq(question2.id)
    end

    it 'returns nil when at end of queue' do
      next_question = service.get_next_priority_question(queue, 2)
      
      expect(next_question).to be_nil
    end

    it 'returns nil when past end of queue' do
      next_question = service.get_next_priority_question(queue, 5)
      
      expect(next_question).to be_nil
    end
  end

  describe 'performance considerations' do
    it 'uses efficient database queries with proper includes' do
      # Create a complex structure to test query efficiency
      create_list(:question, 5, section: section)
      
      # Monitor query count
      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        query_count += 1 unless args.last[:sql].include?('SCHEMA')
      end
      
      service.generate_question_queue
      
      # Should use efficient eager loading
      expect(query_count).to be <= 5
    end

    it 'handles large question sets efficiently' do
      # Create a larger set of questions
      create_list(:question, 50, section: section)
      
      start_time = Time.current
      service.generate_question_queue
      end_time = Time.current
      
      # Should complete quickly even with many questions
      expect(end_time - start_time).to be < 1.second
    end
  end

  describe 'edge cases' do
    context 'with no questions' do
      it 'returns empty queue' do
        empty_project = create(:project, user: user)
        empty_service = InterviewFlowService.new(empty_project)
        
        queue = empty_service.generate_question_queue
        
        expect(queue).to be_empty
      end
    end

    context 'with all questions answered' do
      let!(:question1) { create(:question, section: section, order: 1) }
      let!(:question2) { create(:question, section: section, order: 2) }
      let!(:audio_segment1) { create(:audio_segment, project: project, question: question1) }
      let!(:audio_segment2) { create(:audio_segment, project: project, question: question2) }

      it 'returns empty queue when all questions are answered' do
        queue = service.generate_question_queue
        
        expect(queue).to be_empty
      end
    end

    context 'with circular follow-up references' do
      let!(:question1) { create(:question, section: section, order: 1) }
      let!(:question2) do
        create(:question,
               section: section,
               order: 2,
               is_follow_up: true,
               parent_question: question1)
      end

      it 'handles follow-up questions gracefully' do
        queue = service.generate_question_queue
        
        # Should include both questions without infinite loops
        expect(queue.length).to eq(2)
        expect(queue.map(&:id)).to contain_exactly(question1.id, question2.id)
      end
    end
  end

  describe 'integration with Core.txt requirements' do
    context 'available_questions endpoint requirements' do
      let!(:base_question) { create(:question, section: section, order: 1, is_follow_up: false) }
      let!(:answered_question) { create(:question, section: section, order: 2, is_follow_up: false) }
      let!(:unanswered_question) { create(:question, section: section, order: 3, is_follow_up: false) }
      let!(:followup_question) do
        create(:question,
               section: section,
               order: 4,
               is_follow_up: true,
               parent_question: answered_question)
      end
      let!(:audio_segment) { create(:audio_segment, project: project, question: answered_question) }

      it 'returns list of questions that are not yet answered, omitted, or skipped' do
        queue = service.generate_question_queue
        
        # Should include unanswered questions and urgent follow-ups
        question_ids = queue.map(&:id)
        expect(question_ids).to include(base_question.id, unanswered_question.id, followup_question.id)
        expect(question_ids).not_to include(answered_question.id)
      end

      it 'sorts with urgent follow-up questions appearing first' do
        queue = service.generate_question_queue
        
        # Follow-up whose parent is answered should appear first
        expect(queue.first.id).to eq(followup_question.id)
        expect(queue.first.is_follow_up).to be true
        expect(queue.first.parent_question_id).to eq(answered_question.id)
      end
    end

    context 'question prioritization requirements' do
      let!(:question1) { create(:question, section: section, order: 1) }
      let!(:question2) { create(:question, section: section, order: 2) }
      let!(:followup1) do
        create(:question,
               section: section,
               order: 3,
               is_follow_up: true,
               parent_question: question1)
      end
      let!(:followup2) do
        create(:question,
               section: section,
               order: 4,
               is_follow_up: true,
               parent_question: question1)
      end

      context 'when parent is answered' do
        let!(:audio_segment) { create(:audio_segment, project: project, question: question1) }

        it 'prioritizes all follow-ups for answered parent' do
          queue = service.generate_question_queue
          
          # Both follow-ups should be at the front
          urgent_followups = queue.take(2)
          expect(urgent_followups.map(&:id)).to contain_exactly(followup1.id, followup2.id)
          expect(urgent_followups.all?(&:is_follow_up)).to be true
        end
      end
    end
  end
end