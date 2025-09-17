FactoryBot.define do
  factory :transcript do
    association :project
    status { :ready }
    last_updated { Time.current }
    edited_content { [
      {
        type: "chapter",
        chapterId: 1,
        title: "Introduction",
        text: nil,
        audioSegmentId: nil
      },
      {
        type: "section", 
        sectionId: 1,
        title: "Background",
        text: nil,
        audioSegmentId: nil
      },
      {
        type: "paragraph",
        chapterId: 1,
        sectionId: 1,
        questionId: 1,
        text: "This is a sample paragraph of transcribed content.",
        audioSegmentId: 1
      }
    ].to_json }

    trait :processing_raw do
      status { :processing_raw }
      edited_content { nil }
    end

    trait :empty do
      edited_content { [].to_json }
    end

    trait :complex_content do
      edited_content { [
        {
          type: "chapter",
          chapterId: 1,
          title: "Early Life",
          text: nil,
          audioSegmentId: nil
        },
        {
          type: "section",
          sectionId: 1,
          title: "Childhood",
          text: nil,
          audioSegmentId: nil
        },
        {
          type: "paragraph",
          chapterId: 1,
          sectionId: 1,
          questionId: 1,
          text: "I grew up in a small town where everyone knew everyone.",
          audioSegmentId: 1
        },
        {
          type: "paragraph",
          chapterId: 1,
          sectionId: 1,
          questionId: 2,
          text: "My parents were both teachers, which shaped my values.",
          audioSegmentId: 2
        },
        {
          type: "chapter",
          chapterId: 2,
          title: "Career",
          text: nil,
          audioSegmentId: nil
        },
        {
          type: "paragraph",
          chapterId: 2,
          sectionId: nil,
          questionId: 3,
          text: "My career took an unexpected turn when I discovered technology.",
          audioSegmentId: 3
        }
      ].to_json }
    end
  end
end