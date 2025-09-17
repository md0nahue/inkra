FactoryBot.define do
  factory :interview_preset do
    sequence(:uuid) { |n| SecureRandom.uuid }
    sequence(:title) { |n| "Interview Preset #{n}" }
    sequence(:description) { |n| "Description for interview preset #{n}" }
    category { 'general' }
    icon_name { 'star.fill' }
    order_position { rand(0..999) }
    active { true }
    is_featured { false }

    trait :featured do
      is_featured { true }
    end

    trait :inactive do
      active { false }
    end

    trait :creativity do
      category { 'creativity' }
      icon_name { 'lightbulb.fill' }
    end

    trait :leadership do
      category { 'leadership' }
      icon_name { 'person.3.fill' }
    end

    trait :with_questions do
      after(:create) do |preset|
        create_list(:preset_question, 3, interview_preset: preset)
      end
    end
  end
end