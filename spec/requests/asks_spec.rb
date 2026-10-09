require "rails_helper"

RSpec.describe "Asks", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:ask)   { create(:ask, user: user) }

  let(:valid_params) do
    { ask: { whats_going_on: "We have to be out of our flat by the 30th and we have nowhere lined up yet.",
             asking_for: "both", moment_on: "", vocabulary: "carrying", visibility: "named" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get asks_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post asks_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My asks with only the user's own asks" do
      create(:ask, user: user, whats_going_on: "Mine: please hold my sister in your prayers this week.")
      create(:ask, user: other, whats_going_on: "Someone else: please carry my move with me this month.")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My asks", "Mine: please hold my sister")
      expect(response.body).not_to include("Someone else")
    end

    it "shows the latest reworded title on the dashboard" do
      create(:ask_draft, :completed, ask: ask)
      get asks_path
      expect(CGI.unescapeHTML(response.body)).to include("Dad's heart surgery on the 19th", "reworded")
    end

    it "shows an empty state with no asks" do
      get asks_path
      expect(response.body).to include("Write your first ask")
    end

    it "renders the new form with the labels the UI journey fills" do
      get new_ask_path
      expect(response).to have_http_status(:ok)
      expect(CGI.unescapeHTML(response.body)).to include(
        "What's going on", "What are you asking for?", "The date, if there is one", "Our word for this",
        "Who sees your name", "Create Ask", "988"
      )
    end

    it "creates an ask and redirects to it" do
      expect { post asks_path, params: valid_params }.to change(user.asks, :count).by(1)
      created = Ask.last
      expect(response).to redirect_to(ask_path(created))
      expect(created.moment_on).to be_nil
      expect(created.vocabulary).to eq("carrying")
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post asks_path, params: { ask: valid_params[:ask].merge(whats_going_on: "short") }
      }.not_to change(Ask, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows the ask with the Help me say this button" do
      get ask_path(ask)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ask.whats_going_on, "Help me say this", "never writes a prayer")
    end

    it "lists earlier wordings on the ask page" do
      create(:ask_draft, :completed, ask: ask)
      create(:ask_draft, :failed, ask: ask)
      get ask_path(ask)
      expect(CGI.unescapeHTML(response.body)).to include("Earlier wordings", "Dad's heart surgery on the 19th", "could not be used")
    end

    it "renders the edit form" do
      get edit_ask_path(ask)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit your ask", ask.whats_going_on)
    end

    it "updates an ask" do
      patch ask_path(ask), params: { ask: { vocabulary: "devotional" } }
      expect(response).to redirect_to(ask_path(ask))
      expect(ask.reload.vocabulary).to eq("devotional")
    end

    it "rejects an invalid update with 422" do
      patch ask_path(ask), params: { ask: { visibility: "everyone" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes an ask" do
      ask
      expect { delete ask_path(ask) }.to change(Ask, :count).by(-1)
      expect(response).to redirect_to(asks_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the ask" do
      get ask_path(ask)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_ask_path(ask)
      expect(response).to redirect_to(root_path)
      patch ask_path(ask), params: { ask: { vocabulary: "carrying" } }
      expect(response).to redirect_to(root_path)
      expect { delete ask_path(ask) }.not_to change(Ask, :count)
      expect(response).to redirect_to(root_path)
      expect(ask.reload.vocabulary).to eq("prayer")
    end
  end
end
