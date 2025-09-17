FactoryBot.define do
  factory :section do
    chapter
    title { "Section: #{Faker::Lorem.words(number: 2).join(' ').titleize}" }
    sequence(:order)
    omitted { false }
  end
  
  factory :section_with_questions, parent: :section do
    after(:create) do |section|
      create_list(:question, 3, section: section)
    end
  end
end