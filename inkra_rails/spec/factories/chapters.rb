FactoryBot.define do
  factory :chapter do
    project
    title { "Chapter: #{Faker::Lorem.words(number: 3).join(' ').titleize}" }
    sequence(:order)
    omitted { false }
  end
  
  factory :chapter_with_sections, parent: :chapter do
    after(:create) do |chapter|
      create_list(:section_with_questions, 2, chapter: chapter)
    end
  end
end