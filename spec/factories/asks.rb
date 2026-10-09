FactoryBot.define do
  factory :ask do
    association :user
    whats_going_on { "Could people please hold my dad in their prayers. He has his heart valve surgery on the 19th and he is trying to act like it is nothing." }
    asking_for     { "prayer" }
    moment_on      { Date.new(2026, 11, 19) }
    vocabulary     { "prayer" }
    visibility     { "named" }

    trait :anonymous do
      visibility { "anonymous" }
    end

    trait :no_date do
      moment_on { nil }
    end
  end
end
