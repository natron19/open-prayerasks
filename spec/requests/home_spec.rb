require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows the pitch, the fictional example, crisis resources, and the production link to visitors" do
    get root_path
    expect(response).to have_http_status(:ok)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("A gentler wording", "knee replacement on the 14th", "It did not go as we hoped")
    expect(body).to include("988", "https://prayerasks.com", "Try it free")
  end

  it "sends a signed-in member to their asks" do
    sign_in_as(create(:user))
    get root_path
    expect(response.body).to include("Go to my asks")
  end
end
