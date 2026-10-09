require "rails_helper"

RSpec.describe "db/seeds.rb" do
  def seed!
    allow($stdout).to receive(:puts)
    load Rails.root.join("db/seeds.rb")
  end

  it "seeds the app template and no placeholder, and is safe to run twice" do
    2.times { seed! }
    expect(AiTemplate.pluck(:name)).to contain_exactly("health_ping", "eval_judge_v1", "prayerasks_ask_v1")
    template = AiTemplate.find_by!(name: "prayerasks_ask_v1")
    expect(template.max_output_tokens).to eq(8192)
    expect(template.model).to eq("gemini-2.5-flash")
    expect(template.system_prompt).to include("You never write a prayer, a blessing, or words to be carried.")
    expect(Ask.count).to eq(1)
    expect(AskDraft.count).to eq(1)
  end

  it "gives the demo user one fictional ask with a completed draft that obeys the app's rules" do
    seed!
    ask   = User.find_by!(email: "demo@example.com").asks.sole
    draft = ask.ask_drafts.sole
    expect(draft).to be_completed
    expect(draft.body.length).to be <= ask.whats_going_on.length
    expect(draft.outcome_answers.size).to eq(3)
    expect(draft.moment_on).to eq(ask.moment_on)
    expect(NoPrayerCheck.found_in(draft.gemini_raw, ask.whats_going_on)).to be_empty
    expect(draft.stale?).to be(false)
  end
end
