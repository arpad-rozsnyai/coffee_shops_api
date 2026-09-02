require "rails_helper"

RSpec.describe "GET /", type: :request do
  it "returns the home page without touching the coffee shop data" do
    expect(CoffeeShopsApiSchema).not_to receive(:execute)

    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
  end

  it "mentions the GraphQL endpoint outside development" do
    get "/"

    expect(response.body).to include("POST /graphql")
  end

  it "links to GraphiQL in a new tab in development" do
    allow(Rails.env).to receive(:development?).and_return(true)

    get "/"

    expect(response.body).to include('href="/graphiql"')
    expect(response.body).to include('target="_blank"')
    expect(response.body).to include('rel="noopener noreferrer"')
  end
end
