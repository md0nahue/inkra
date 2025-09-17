FactoryBot.define do
  factory :preset_question do
    interview_preset
    sequence(:chapter_title) { |n| "Chapter #{(n - 1) / 5 + 1}" }
    sequence(:section_title) { |n| "Section #{(n - 1) / 2 + 1}" }
    sequence(:question_text) { |n| "What is your question number #{n}?" }
    chapter_order { 1 }
    section_order { 1 }
    sequence(:question_order) { |n| n }

    trait :chapter_one do
      chapter_title { 'Chapter 1' }
      chapter_order { 1 }
    end

    trait :chapter_two do
      chapter_title { 'Chapter 2' }
      chapter_order { 2 }
    end

    trait :section_one do
      section_title { 'Section 1' }
      section_order { 1 }
    end

    trait :section_two do
      section_title { 'Section 2' }
      section_order { 2 }
    end
  end
end