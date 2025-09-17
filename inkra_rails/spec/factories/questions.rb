FactoryBot.define do
  factory :question do
    section
    text { "#{Faker::Lorem.sentence.chomp('.')}?" }
    sequence(:order)
    omitted { false }
    is_follow_up { false }
    parent_question { nil }

    trait :followup do
      is_follow_up { true }
      association :parent_question, factory: :question
    end

    trait :omitted do
      omitted { true }
    end

    trait :skipped do
      skipped { true }
    end
  end
end