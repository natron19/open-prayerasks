require "rails_helper"

RSpec.describe AskDraft, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:ask_draft)).to be_valid
    end

    it "requires an ask" do
      expect(build(:ask_draft, ask: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      AskDraft::STATUSES.each { |s| expect(build(:ask_draft, status: s)).to be_valid }
      expect(build(:ask_draft, status: "unknown")).not_to be_valid
    end

    it "lists the statuses" do
      expect(AskDraft::STATUSES).to eq(%w[pending completed failed])
    end
  end

  describe "associations" do
    it "has a user through its ask" do
      draft = create(:ask_draft)
      expect(draft.user).to eq(draft.ask.user)
    end
  end

  describe "defaults" do
    it "starts pending with empty lists" do
      draft = AskDraft.create!(ask: create(:ask))
      expect(draft.status).to eq("pending")
      expect([ draft.practical_help_ideas, draft.outcome_answers, draft.privacy_flags ]).to all(eq([]))
    end
  end

  describe "#stale?" do
    it "is true when the ask changed after the draft" do
      draft = create(:ask_draft, :completed, generated_at: 1.hour.ago)
      draft.ask.update!(vocabulary: "devotional")
      expect(draft.stale?).to be(true)
    end

    it "is false when the draft is newer than the ask" do
      draft = create(:ask_draft, :completed, generated_at: 1.minute.from_now)
      expect(draft.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    it "includes the wording, the date, the outcome question, and what the member wrote" do
      draft = create(:ask_draft, :completed)
      md = draft.to_markdown
      expect(md).to include("# #{draft.title}", draft.body, "_What changed:_ #{draft.what_changed}")
      expect(md).to include("Heart valve surgery: 2026-11-19")
      expect(md).to include(draft.outcome_question, *draft.outcome_answers.map { |a| "- #{a}" })
      expect(md).to include("## What you wrote", draft.ask.whats_going_on)
      expect(md).to include("not a prayer")
      expect(md).not_to include("## Practical help", "## Details that could identify you")
    end

    it "lists practical help ideas and privacy flags when present" do
      draft = create(:ask_draft, :with_help, privacy_flags: [ "The hospital and the date together" ])
      md = draft.to_markdown
      expect(md).to include("## Practical help people could offer", "- **Bring a meal the evening he is home**: Your stepmum is exhausted.")
      expect(md).to include("## Details that could identify you", "- The hospital and the date together")
    end

    it "names the file after the title" do
      draft = create(:ask_draft, :completed)
      expect(draft.markdown_filename).to eq("dad-s-heart-surgery-on-the-19th-reworded.md")
    end
  end
end
