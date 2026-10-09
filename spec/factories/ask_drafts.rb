FactoryBot.define do
  factory :ask_draft do
    association :ask
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status               { "completed" }
      generated_at         { Time.current }
      gemini_raw           { "{}" }
      title                { "Dad's heart surgery on the 19th" }
      body                 { "Please hold my dad in your prayers. His heart valve surgery is on the 19th, and he is more worried than he lets on." }
      what_changed         { "Put the date in the first lines and kept your words about your dad." }
      moment_name          { "Heart valve surgery" }
      moment_on            { Date.new(2026, 11, 19) }
      practical_help_ideas { [] }
      outcome_question     { "Your dad's surgery was on the 19th. When you're ready, how did it go?" }
      outcome_answers      { [ "It was answered", "It changed", "It did not go as we hoped" ] }
      privacy_flags        { [] }
    end

    trait :with_help do
      completed
      practical_help_ideas do
        [
          { "idea" => "Bring a meal the evening he is home", "why" => "Your stepmum is exhausted." },
          { "idea" => "Drive the family to the hospital", "why" => "It saves one more thing on surgery day." }
        ]
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
