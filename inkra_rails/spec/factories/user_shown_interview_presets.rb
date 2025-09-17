FactoryBot.define do
  factory :user_shown_interview_preset do
    user
    interview_preset
    shown_at { Time.current }

    trait :old do
      shown_at { 30.days.ago }
    end

    trait :recent do
      shown_at { 1.day.ago }
    end
  end
end