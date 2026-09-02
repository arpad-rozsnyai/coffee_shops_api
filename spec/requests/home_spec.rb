require "rails_helper"

RSpec.describe "GET /", type: :request do
  it "returns the home page without touching the coffee shop data pipeline" do
    expect(CoffeeShopRepository).not_to receive(:new)

    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
  end

  it "links to the API docs page, opening in a new tab safely" do
    get "/"

    expect(response.body).to include('href="/api-docs"')
    expect(response.body).to include('target="_blank"')
    expect(response.body).to include('rel="noopener noreferrer"')
  end
end
