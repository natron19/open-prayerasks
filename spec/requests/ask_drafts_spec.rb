require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe "AskDrafts", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:ask)   { create(:ask, user: user) }

  # A valid prayerasks_ask_v1 answer for the factory ask (prayer only, named, dated 2026-11-19).
  let(:result) do
    {
      "reworded_ask"         => { "title" => "Dad's heart surgery on the 19th",
                                  "body"  => "Please hold my dad in your prayers. His heart valve surgery is on the 19th." },
      "what_changed"         => "Put the date first and kept your words.",
      "moment"               => { "name" => "Heart valve surgery", "occurs_on" => "2026-11-19" },
      "practical_help_ideas" => [],
      "outcome_question"     => { "question" => "Your dad's surgery was on the 19th. How did it go?",
                                  "answers"  => [ "It was answered", "It changed", "It did not go as we hoped" ] },
      "privacy_flags"        => []
    }
  end

  def run_draft(target = ask)
    post ask_drafts_path(target)
  end

  def with(changes)
    result.merge(changes).to_json
  end

  describe "POST /asks/:ask_id/drafts" do
    context "when not signed in" do
      it "redirects to sign in" do
        run_draft
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(result.to_json)
      end

      it "calls GeminiService with the template and the ask's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "prayerasks_ask_v1",
          variables: {
            whats_going_on: ask.whats_going_on,
            input_length:   ask.whats_going_on.length.to_s,
            asking_for:     Ask::ASKING_FOR_PROMPTS["prayer"],
            moment_on:      "2026-11-19",
            vocabulary:     "prayer",
            visibility:     Ask::VISIBILITY_PROMPTS["named"]
          }
        ).and_return(result.to_json)
        run_draft
      end

      it "creates a completed draft with the parsed fields and the raw response" do
        expect { run_draft }.to change(AskDraft, :count).by(1)
        draft = AskDraft.last
        expect(draft.status).to eq("completed")
        expect(draft.gemini_raw).to eq(result.to_json)
        expect(draft.title).to eq("Dad's heart surgery on the 19th")
        expect(draft.body).to eq(result.dig("reworded_ask", "body"))
        expect(draft.moment_name).to eq("Heart valve surgery")
        expect(draft.moment_on).to eq(Date.new(2026, 11, 19))
        expect(draft.outcome_answers.size).to eq(3)
        expect(draft.generated_at).to be_present
      end

      it "redirects to the result page" do
        run_draft
        expect(response).to redirect_to(ask_draft_path(ask, AskDraft.last))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{result.to_json}\n```")
        run_draft
        expect(AskDraft.last.status).to eq("completed")
      end

      it "accepts a null moment when the member gave no date" do
        ask.update!(moment_on: nil)
        gemini_returns(with("moment" => nil))
        run_draft
        draft = AskDraft.last
        expect(draft.status).to eq("completed")
        expect(draft.moment_on).to be_nil
      end

      it "stores practical help ideas and privacy flags for an anonymous ask that asks for both" do
        ask.update!(asking_for: "both", visibility: "anonymous")
        ideas = [ { "idea" => "Drive the family to the hospital", "why" => "It is one less thing that day." } ]
        gemini_returns(with("practical_help_ideas" => ideas, "privacy_flags" => [ "The surgery date" ]))
        run_draft
        draft = AskDraft.last
        expect(draft.status).to eq("completed")
        expect(draft.practical_help_ideas).to eq(ideas)
        expect(draft.privacy_flags).to eq([ "The surgery date" ])
      end

      it "accepts the seeded example's raw response for the seeded ask" do
        allow($stdout).to receive(:puts)
        load Rails.root.join("db/seeds.rb")
        demo_ask = User.find_by!(email: "demo@example.com").asks.sole
        sign_in_as(demo_ask.user)
        gemini_returns(demo_ask.ask_drafts.sole.gemini_raw)
        run_draft(demo_ask)
        expect(demo_ask.ask_drafts.order(:created_at).last.status).to eq("completed")
      end

      it "allows a prayer marker the member wrote themselves" do
        ask.update!(whats_going_on: "God bless all of you who have sent cards. Please keep my dad in your prayers before his surgery on the 19th.")
        gemini_returns(with("reworded_ask" => { "title" => "Dad's surgery", "body" => "God bless all of you who sent cards. Please keep my dad in your prayers before his surgery on the 19th." }))
        run_draft
        expect(AskDraft.last.status).to eq("completed")
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      long_body = "Please hold my dad in your prayers. " * 10
      {
        "is not JSON"                                => "this is not json at all",
        "is a JSON array"                            => "[1, 2]",
        "has no reworded_ask body"                   => { "reworded_ask" => { "title" => "A title" } },
        "has a body longer than the input"           => { "reworded_ask" => { "title" => "A title", "body" => long_body } },
        "has a title over 80 characters"             => { "reworded_ask" => { "title" => "t" * 81, "body" => "Short." } },
        "has no what_changed"                        => { "what_changed" => " " },
        "has two outcome answers"                    => { "outcome_question" => { "question" => "How did it go?", "answers" => [ "Answered", "Changed" ] } },
        "has four outcome answers"                   => { "outcome_question" => { "question" => "How did it go?", "answers" => %w[A B C D] } },
        "has a blank outcome answer"                 => { "outcome_question" => { "question" => "How did it go?", "answers" => [ "Answered", " ", "Changed" ] } },
        "has four practical help ideas"              => { "practical_help_ideas" => Array.new(4) { { "idea" => "A lift", "why" => "Helps." } } },
        "suggests help when only prayer was asked"   => { "practical_help_ideas" => [ { "idea" => "A meal", "why" => "Helps." } ] },
        "changes the member's date"                  => { "moment" => { "name" => "Surgery", "occurs_on" => "2026-11-20" } },
        "drops the member's date"                    => { "moment" => nil },
        "has seven privacy flags"                    => { "privacy_flags" => Array.new(7) { |i| "Detail #{i}" } },
        "ends with Amen"                             => { "reworded_ask" => { "title" => "Dad's surgery", "body" => "Please hold my dad close. Amen." } },
        "opens with Dear God"                        => { "reworded_ask" => { "title" => "Dad's surgery", "body" => "Dear God, please be with my dad on the 19th." } },
        "says we pray in the outcome question"       => { "outcome_question" => { "question" => "We pray it went well. How did it go?", "answers" => %w[Answered Changed Otherwise] } },
        "adds a blessing to what changed"            => { "what_changed" => "Added a blessing: bless you all." },
        "cites scripture"                            => { "reworded_ask" => { "title" => "Dad's surgery", "body" => "Please hold my dad close (Isaiah 41:10)." } }
      }.each do |description, change|
        it "marks the draft failed and keeps the raw text when the response #{description}" do
          text = change.is_a?(Hash) ? with(change) : change
          gemini_returns(text)

          expect { run_draft }.to change(AskDraft, :count).by(1)
          draft = AskDraft.last
          expect(draft.status).to eq("failed")
          expect(draft.gemini_raw).to eq(text)
          expect(draft.failure_reason).to be_present
          expect(response).to redirect_to(ask_draft_path(ask, draft))
        end
      end

      it "fails a response that adds a date when the member gave none" do
        ask.update!(moment_on: nil)
        gemini_returns(result.to_json)
        run_draft
        expect(AskDraft.last.failure_reason).to include("added a date")
      end

      it "explains a prayer in the output on the result page, with Retry and no download" do
        gemini_returns(with("reworded_ask" => { "title" => "Dad's surgery", "body" => "Lord, we lift up my dad. Amen." }))
        run_draft
        draft = AskDraft.last
        expect(draft.failure_reason).to include("prayer or blessing words", "Lord", "Amen")

        follow_redirect!
        expect(response.body).to include("could not be used", "which this app never writes", "Retry", "Lord, we lift up my dad.")
        expect(response.body).not_to include("Download .md")
      end

      it "explains a body that is longer than what the member wrote" do
        gemini_returns(with("reworded_ask" => { "title" => "Dad", "body" => "x" * (ask.whats_going_on.length + 1) }))
        run_draft
        expect(AskDraft.last.failure_reason).to include("longer than what you wrote")
      end
    end

    context "when the ask contains crisis terms" do
      before do
        allow($stdout).to receive(:puts)
        load Rails.root.join("db/seeds.rb")
        sign_in_as(user)
        ask.update!(whats_going_on: "Honestly I want to end my life and I don't know who to talk to.")
      end

      it "shows the 988 message, makes no AI call, and logs the block (real GeminiService, no stub)" do
        expect(Faraday).not_to receive(:new)
        expect { run_draft }.to change { LlmRequest.where(status: "gatekeeper_blocked").count }.by(1)
          .and(not_change(AskDraft, :count))
          .and(not_change { LlmRequest.where(status: "success").count })
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("988", "Suicide &amp; Crisis Lifeline")
        expect(response.body).not_to include("couldn&#39;t be processed")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::CrisisError         => "988",
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no draft" do
          gemini_raises(error_class)
          expect { run_draft }.not_to change(AskDraft, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(CGI.unescapeHTML(response.body)).to include(message)
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the ask, calls no AI, and creates no draft" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { run_draft }.not_to change(AskDraft, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th draft within a minute" do
        sign_in_as(user)
        gemini_returns(result.to_json)
        10.times { run_draft }
        expect(response).to have_http_status(:redirect)
        run_draft
        expect(response).to have_http_status(:too_many_requests)
        expect(AskDraft.count).to eq(10)
      end
    end
  end

  describe "GET /asks/:ask_id/drafts (the error page's Try again)" do
    it "redirects to the ask" do
      sign_in_as(user)
      get ask_drafts_path(ask)
      expect(response).to redirect_to(ask_path(ask))
    end
  end

  describe "GET /asks/:ask_id/drafts/:id" do
    it "shows both wordings, the date, the outcome question, the actions, and the disclaimer" do
      draft = create(:ask_draft, :completed, ask: ask, generated_at: 1.minute.from_now)
      sign_in_as(user)
      get ask_draft_path(ask, draft)
      expect(response).to have_http_status(:ok)
      body = CGI.unescapeHTML(response.body)
      expect(body).to include(
        "What you wrote", ask.whats_going_on, "A gentler wording", draft.title, draft.body,
        "What changed:", draft.what_changed, "The date", "Heart valve surgery",
        "be asked afterwards", draft.outcome_question, *draft.outcome_answers,
        "Download .md", "Show raw response", "AI-generated.", "not a prayer"
      )
      expect(body).not_to include("Practical help people could offer", "Details that could identify you", "You have edited your ask")
    end

    it "shows practical help ideas and privacy flags for an anonymous ask" do
      ask.update!(visibility: "anonymous", asking_for: "both")
      draft = create(:ask_draft, :with_help, ask: ask, generated_at: 1.minute.from_now, privacy_flags: [ "The surgery date" ])
      sign_in_as(user)
      get ask_draft_path(ask, draft)
      expect(response.body).to include("Practical help people could offer", "Bring a meal the evening he is home",
                                       "Details that could identify you", "The surgery date")
    end

    it "shows the reason, Retry, and the raw response for a failed draft, with no download" do
      draft = create(:ask_draft, :failed, ask: ask)
      sign_in_as(user)
      get ask_draft_path(ask, draft)
      expect(response.body).to include("could not be used", draft.failure_reason, "Retry", "malformed response")
      expect(response.body).not_to include("Download .md")
    end

    it "warns when the ask changed after the draft" do
      draft = create(:ask_draft, :completed, ask: ask, generated_at: 1.hour.ago)
      ask.update!(vocabulary: "devotional")
      sign_in_as(user)
      get ask_draft_path(ask, draft)
      expect(response.body).to include("You have edited your ask since this wording")
    end

    it "does not show another user's draft" do
      draft = create(:ask_draft, :completed, ask: ask)
      sign_in_as(other)
      get ask_draft_path(ask, draft)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a draft under a different ask of the same user" do
      draft = create(:ask_draft, :completed, ask: ask)
      sign_in_as(user)
      get ask_draft_path(create(:ask, user: user), draft)
      expect(response).to redirect_to(root_path)
    end
  end
end
