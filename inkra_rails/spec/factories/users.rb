FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    admin { false }
    interests { [] }
    
    trait :admin do
      admin { true }
    end

    trait :with_interests do
      interests { ['fiction_writing', 'personal_growth'] }
    end
  end
end
