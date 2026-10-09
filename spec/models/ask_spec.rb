require "rails_helper"

RSpec.describe Ask, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:ask)).to be_valid
    end

    it "requires a user" do
      expect(build(:ask, user: nil)).not_to be_valid
    end

    it "requires what's going on, 20 to 2,000 characters" do
      expect(build(:ask, whats_going_on: "")).not_to be_valid
      expect(build(:ask, whats_going_on: "too short")).not_to be_valid
      expect(build(:ask, whats_going_on: "a" * 20)).to be_valid
      expect(build(:ask, whats_going_on: "a" * 2000)).to be_valid
      expect(build(:ask, whats_going_on: "a" * 2001)).not_to be_valid
    end

    it "accepts every known asking_for, vocabulary, and visibility and rejects others" do
      Ask::ASKING_FOR.each   { |v| expect(build(:ask, asking_for: v)).to be_valid }
      Ask::VOCABULARIES.each { |v| expect(build(:ask, vocabulary: v)).to be_valid }
      Ask::VISIBILITIES.each { |v| expect(build(:ask, visibility: v)).to be_valid }
      expect(build(:ask, asking_for: "money")).not_to be_valid
      expect(build(:ask, vocabulary: "worship")).not_to be_valid
      expect(build(:ask, visibility: "circle")).not_to be_valid
    end

    it "lists the enum values" do
      expect(Ask::ASKING_FOR).to eq(%w[prayer practical_help both])
      expect(Ask::VOCABULARIES).to eq(%w[prayer devotional carrying])
      expect(Ask::VISIBILITIES).to eq(%w[named anonymous])
    end

    it "makes the date optional" do
      expect(build(:ask, :no_date)).to be_valid
    end
  end

  describe "associations" do
    it "destroys its drafts" do
      ask = create(:ask)
      create(:ask_draft, :completed, ask: ask)
      expect { ask.destroy }.to change(AskDraft, :count).by(-1)
    end

    it "is destroyed with its user" do
      ask = create(:ask)
      expect { ask.user.destroy }.to change(Ask, :count).by(-1)
    end

    it "finds the latest draft by generated_at" do
      ask   = create(:ask)
      older = create(:ask_draft, :completed, ask: ask, generated_at: 2.hours.ago)
      newer = create(:ask_draft, :completed, ask: ask, generated_at: 1.minute.ago)
      expect(ask.latest_ask_draft).to eq(newer)
      expect(ask.latest_ask_draft).not_to eq(older)
    end
  end

  describe "#ai_variables" do
    it "sends the member's words, their length, and the prompt phrases, and nothing about the user" do
      ask  = create(:ask, :anonymous, asking_for: "both", vocabulary: "carrying")
      vars = ask.ai_variables
      expect(vars).to eq(
        whats_going_on: ask.whats_going_on,
        input_length:   ask.whats_going_on.length.to_s,
        asking_for:     Ask::ASKING_FOR_PROMPTS["both"],
        moment_on:      "2026-11-19",
        vocabulary:     "carrying",
        visibility:     Ask::VISIBILITY_PROMPTS["anonymous"]
      )
      expect(vars.values.join(" ")).not_to include(ask.user.name, ask.user.email)
    end

    it "says when no date was given" do
      expect(build(:ask, :no_date).ai_variables[:moment_on]).to eq("No date given")
    end

    it "fills every variable the seeded template uses" do
      allow($stdout).to receive(:puts)
      load Rails.root.join("db/seeds.rb")
      template = AiTemplate.find_by!(name: "prayerasks_ask_v1")
      expect(template.variable_names.map(&:to_sym)).to match_array(build(:ask).ai_variables.keys)
    end
  end

  describe "#summary" do
    it "shortens the member's words on a word boundary" do
      ask = build(:ask, whats_going_on: "word " * 40)
      expect(ask.summary(30).length).to be <= 30
      expect(ask.summary(30)).to end_with("...")
    end
  end
end
