require 'rails_helper'

RSpec.describe TranscriptContentAssemblerService, type: :service do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user, status: 'transcribing') }
  let(:chapter) { create(:chapter, project: project) }
  let(:section) { create(:section, chapter: chapter) }
  let(:question1) { create(:question, section: section, order: 1) }
  let(:question2) { create(:question, section: section, order: 2) }
  
  let!(:audio_segment1) do
    create(:audio_segment, :transcribed, 
           project: project, 
           question: question1,
           transcription_text: "I started my career in technology because I was fascinated by the potential to solve real-world problems.")
  end
  
  let!(:audio_segment2) do
    create(:audio_segment, :transcribed, 
           project: project, 
           question: question2,
           transcription_text: "The biggest challenge was learning to work with complex systems and understanding the business impact.")
  end

  describe '.process_transcript' do
    context 'when processing is successful' do
      it 'creates a structured transcript from audio segments' do
        result = TranscriptProcessorService.process_transcript(project.id)
        
        expect(result[:success]).to be true
        expect(result[:transcript_id]).to be_present
        
        project.reload
        expect(project.status).to eq('completed')
        expect(project.transcript).to be_present
        expect(project.transcript.status).to eq('ready')
      end

      it 'generates proper content structure with chapters, sections, and paragraphs' do
        TranscriptProcessorService.process_transcript(project.id)
        
        transcript = project.reload.transcript
        content = transcript.content_json
        
        # Should have chapter header
        chapter_content = content.find { |item| item['type'] == 'chapter' }
        expect(chapter_content).to be_present
        expect(chapter_content['chapterId']).to eq(chapter.id)
        expect(chapter_content['title']).to eq(chapter.title)
        
        # Should have section header
        section_content = content.find { |item| item['type'] == 'section' }
        expect(section_content).to be_present
        expect(section_content['sectionId']).to eq(section.id)
        expect(section_content['title']).to eq(section.title)
        
        # Should have paragraph content
        paragraph_contents = content.select { |item| item['type'] == 'paragraph' }
        expect(paragraph_contents.length).to eq(2)
        
        first_paragraph = paragraph_contents.find { |p| p['questionId'] == question1.id }
        expect(first_paragraph['text']).to include('started my career')
        expect(first_paragraph['audioSegmentId']).to eq(audio_segment1.id)
        
        second_paragraph = paragraph_contents.find { |p| p['questionId'] == question2.id }
        expect(second_paragraph['text']).to include('biggest challenge')
        expect(second_paragraph['audioSegmentId']).to eq(audio_segment2.id)
      end

      it 'orders content properly based on question order' do
        TranscriptProcessorService.process_transcript(project.id)
        
        transcript = project.reload.transcript
        paragraph_contents = transcript.content_json.select { |item| item['type'] == 'paragraph' }
        
        # Questions should be ordered by their order attribute
        expect(paragraph_contents.first['questionId']).to eq(question1.id)
        expect(paragraph_contents.second['questionId']).to eq(question2.id)
      end

      it 'updates transcript timestamps' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        
        TranscriptProcessorService.process_transcript(project.id)
        
        transcript = project.reload.transcript
        expect(transcript.last_updated).to eq(freeze_time)
      end

      it 'updates project last_modified_at timestamp' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        
        TranscriptProcessorService.process_transcript(project.id)
        
        project.reload
        expect(project.last_modified_at).to eq(freeze_time)
      end
    end

    context 'when transcript already exists' do
      let!(:existing_transcript) { create(:transcript, project: project, status: 'processing') }

      it 'updates the existing transcript instead of creating a new one' do
        expect {
          TranscriptProcessorService.process_transcript(project.id)
        }.not_to change(Transcript, :count)
        
        existing_transcript.reload
        expect(existing_transcript.status).to eq('ready')
        expect(existing_transcript.content_json).to be_present
      end
    end

    context 'when no transcribed segments exist' do
      before do
        audio_segment1.update!(upload_status: 'success')
        audio_segment2.update!(upload_status: 'success')
      end

      it 'returns error result' do
        result = TranscriptProcessorService.process_transcript(project.id)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('No transcribed content available')
      end

      it 'does not update project status' do
        TranscriptProcessorService.process_transcript(project.id)
        
        project.reload
        expect(project.status).to eq('transcribing')
      end
    end

    context 'when project does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          TranscriptProcessorService.process_transcript(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when an exception occurs during processing' do
      before do
        allow(TranscriptProcessorService).to receive(:generate_structured_content)
          .and_raise(StandardError, 'Processing failed')
      end

      it 'handles the exception gracefully' do
        result = TranscriptProcessorService.process_transcript(project.id)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Processing failed')
        
        project.reload
        expect(project.status).to eq('failed')
      end
    end

    context 'when transcript update fails' do
      before do
        allow_any_instance_of(Transcript).to receive(:update!)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'handles database errors gracefully' do
        result = TranscriptProcessorService.process_transcript(project.id)
        
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
        
        project.reload
        expect(project.status).to eq('failed')
      end
    end
  end

  describe '.generate_structured_content' do
    it 'creates properly structured content array' do
      content = TranscriptProcessorService.send(:generate_structured_content, project, [audio_segment1, audio_segment2])
      
      expect(content).to be_an(Array)
      expect(content.length).to be >= 4 # chapter + section + 2 paragraphs
      
      # Verify content types are present
      types = content.map { |item| item[:type] }
      expect(types).to include('chapter', 'section', 'paragraph')
    end

    it 'handles audio segments without questions' do
      segment_without_question = create(:audio_segment, :transcribed, 
                                       project: project, 
                                       question: nil,
                                       transcription_text: "This is unassigned content.")
      
      content = TranscriptProcessorService.send(:generate_structured_content, project, [segment_without_question])
      
      expect(content).to be_an(Array)
      # Should still try to process the segment even without a question
    end

    context 'with multiple chapters and sections' do
      let(:chapter2) { create(:chapter, project: project, order: 2) }
      let(:section2) { create(:section, chapter: chapter2, order: 1) }
      let(:question3) { create(:question, section: section2, order: 1) }
      let!(:audio_segment3) do
        create(:audio_segment, :transcribed, 
               project: project, 
               question: question3,
               transcription_text: "This is content for a different chapter.")
      end

      it 'properly groups content by chapters and sections' do
        all_segments = [audio_segment1, audio_segment2, audio_segment3]
        content = TranscriptProcessorService.send(:generate_structured_content, project, all_segments)
        
        # Should have content for both chapters
        chapter_items = content.select { |item| item[:type] == 'chapter' }
        expect(chapter_items.length).to eq(2)
        
        # Should have content for both sections
        section_items = content.select { |item| item[:type] == 'section' }
        expect(section_items.length).to eq(2)
        
        # Should have all paragraphs
        paragraph_items = content.select { |item| item[:type] == 'paragraph' }
        expect(paragraph_items.length).to eq(3)
      end

      it 'maintains proper ordering by chapter and section order' do
        all_segments = [audio_segment3, audio_segment1, audio_segment2] # Deliberately out of order
        content = TranscriptProcessorService.send(:generate_structured_content, project, all_segments)
        
        chapter_items = content.select { |item| item[:type] == 'chapter' }
        
        # First chapter should come first
        first_chapter_index = content.index { |item| item[:type] == 'chapter' && item[:chapterId] == chapter.id }
        second_chapter_index = content.index { |item| item[:type] == 'chapter' && item[:chapterId] == chapter2.id }
        
        expect(first_chapter_index).to be < second_chapter_index
      end
    end
  end

  describe '.structure_transcription_text' do
    it 'splits long text into logical paragraphs' do
      long_text = "This is the first sentence. However, this is a contrasting point. " \
                  "Additionally, here is more information. Finally, this is the conclusion."
      
      paragraphs = TranscriptProcessorService.send(:structure_transcription_text, long_text, "Tell me about your experience")
      
      expect(paragraphs).to be_an(Array)
      expect(paragraphs.length).to be > 1
      paragraphs.each do |paragraph|
        expect(paragraph.length).to be > 10
      end
    end

    it 'handles short text appropriately' do
      short_text = "This is a short response."
      
      paragraphs = TranscriptProcessorService.send(:structure_transcription_text, short_text, "Short question")
      
      expect(paragraphs).to eq([short_text])
    end

    it 'filters out very short paragraphs' do
      text_with_short_fragments = "This is a good paragraph. Um. This is another good paragraph with substance."
      
      paragraphs = TranscriptProcessorService.send(:structure_transcription_text, text_with_short_fragments, "Question")
      
      # Should filter out the "Um." fragment
      expect(paragraphs.all? { |p| p.length >= 10 }).to be true
    end
  end

  describe '.clean_transcription_text' do
    it 'removes excessive filler words' do
      dirty_text = "So, um, I think, you know, that technology is, like, really important, you know?"
      
      cleaned = TranscriptProcessorService.send(:clean_transcription_text, dirty_text)
      
      expect(cleaned).not_to include('um', 'you know', 'like')
      expect(cleaned).to include('technology', 'important')
    end

    it 'normalizes whitespace' do
      messy_text = "This  has    too   much     spacing."
      
      cleaned = TranscriptProcessorService.send(:clean_transcription_text, messy_text)
      
      expect(cleaned).to eq("This has too much spacing.")
    end

    it 'ensures proper sentence endings' do
      text_without_ending = "This sentence has no ending"
      
      cleaned = TranscriptProcessorService.send(:clean_transcription_text, text_without_ending)
      
      expect(cleaned).to end_with('.')
    end

    it 'fixes multiple periods' do
      text_with_ellipsis = "This has too many periods..."
      
      cleaned = TranscriptProcessorService.send(:clean_transcription_text, text_with_ellipsis)
      
      expect(cleaned).to eq("This has too many periods.")
    end
  end

  describe '.improve_paragraph_structure' do
    it 'capitalizes sentences properly' do
      poor_text = "this is not capitalized. neither is this sentence."
      
      improved = TranscriptProcessorService.send(:improve_paragraph_structure, poor_text)
      
      expect(improved).to eq("This is not capitalized. Neither is this sentence.")
    end

    it 'capitalizes standalone "I"' do
      text_with_i = "i think that i am correct."
      
      improved = TranscriptProcessorService.send(:improve_paragraph_structure, text_with_i)
      
      expect(improved).to include("I think that I am correct.")
    end

    it 'fixes spacing around punctuation' do
      text_with_spacing = "This has bad spacing , and punctuation ."
      
      improved = TranscriptProcessorService.send(:improve_paragraph_structure, text_with_spacing)
      
      expect(improved).to eq("This has bad spacing, and punctuation.")
    end

    it 'ensures proper sentence ending' do
      text_without_ending = "This needs an ending"
      
      improved = TranscriptProcessorService.send(:improve_paragraph_structure, text_without_ending)
      
      expect(improved).to end_with('.')
    end

    it 'preserves existing proper punctuation' do
      well_formatted_text = "This is already well formatted! Isn't it great?"
      
      improved = TranscriptProcessorService.send(:improve_paragraph_structure, well_formatted_text)
      
      expect(improved).to eq(well_formatted_text)
    end
  end

  describe 'integration with complex project structure' do
    let!(:complex_project) { create(:project, user: user, status: 'transcribing') }
    let!(:chapter1) { create(:chapter, project: complex_project, title: "Early Life", order: 1) }
    let!(:chapter2) { create(:chapter, project: complex_project, title: "Career", order: 2) }
    let!(:section1_1) { create(:section, chapter: chapter1, title: "Childhood", order: 1) }
    let!(:section1_2) { create(:section, chapter: chapter1, title: "Education", order: 2) }
    let!(:section2_1) { create(:section, chapter: chapter2, title: "First Job", order: 1) }
    
    let!(:q1) { create(:question, section: section1_1, order: 1) }
    let!(:q2) { create(:question, section: section1_1, order: 2) }
    let!(:q3) { create(:question, section: section1_2, order: 1) }
    let!(:q4) { create(:question, section: section2_1, order: 1) }
    
    before do
      create(:audio_segment, :transcribed, project: complex_project, question: q1, transcription_text: "I grew up in a small town.")
      create(:audio_segment, :transcribed, project: complex_project, question: q2, transcription_text: "My family was very supportive.")
      create(:audio_segment, :transcribed, project: complex_project, question: q3, transcription_text: "I studied computer science in college.")
      create(:audio_segment, :transcribed, project: complex_project, question: q4, transcription_text: "My first job was at a startup.")
    end

    it 'processes complex project structure correctly' do
      result = TranscriptProcessorService.process_transcript(complex_project.id)
      
      expect(result[:success]).to be true
      
      transcript = complex_project.reload.transcript
      content = transcript.content_json
      
      # Verify structure integrity
      expect(content.count { |item| item['type'] == 'chapter' }).to eq(2)
      expect(content.count { |item| item['type'] == 'section' }).to eq(3)
      expect(content.count { |item| item['type'] == 'paragraph' }).to eq(4)
      
      # Verify ordering - chapters should be in order
      chapter_indices = []
      content.each_with_index do |item, index|
        if item['type'] == 'chapter'
          chapter_indices << { id: item['chapterId'], index: index }
        end
      end
      
      expect(chapter_indices.first[:id]).to eq(chapter1.id)
      expect(chapter_indices.second[:id]).to eq(chapter2.id)
      expect(chapter_indices.first[:index]).to be < chapter_indices.second[:index]
    end
  end
end