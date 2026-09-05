require "rails_helper"

RSpec.describe "POST /graphql (mutations)", type: :request do
  let(:user) { create(:user) }
  let(:access_token) { JwtEncoder.new(user: user, token_type: :access).call.first }
  let(:auth_headers) { { "Authorization" => "Bearer #{access_token}" } }

  def post_graphql(query, variables: {}, headers: auth_headers)
    post "/graphql", params: { query: query, variables: variables.to_json }, headers: headers
  end

  describe "createCoffeeShop" do
    def create_mutation
      <<~GRAPHQL
        mutation($name: String!, $x: Float!, $y: Float!, $address: String!, $openUntil: String!) {
          createCoffeeShop(name: $name, x: $x, y: $y, address: $address, openUntil: $openUntil) {
            coffeeShop {
              name
              x
              y
              address
              openUntil
            }
            errors
          }
        }
      GRAPHQL
    end

    it "creates and persists a coffee shop with the given attributes" do
      post_graphql(create_mutation, variables: {
        name: "Starbucks", x: 1.0, y: 2.0, address: "123 Main St", openUntil: "9pm"
      })

      payload = response.parsed_body.dig("data", "createCoffeeShop")
      expect(payload["errors"]).to eq([])
      expect(payload["coffeeShop"]).to include(
        "name" => "Starbucks", "x" => 1.0, "y" => 2.0, "address" => "123 Main St", "openUntil" => "9pm"
      )
      expect(CoffeeShop.find_by(name: "Starbucks")).to be_present
    end

    it "returns a variable coercion error instead of executing the mutation when address is omitted" do
      post "/graphql", params: {
        query: "mutation($name: String!, $x: Float!, $y: Float!, $openUntil: String!) { " \
          "createCoffeeShop(name: $name, x: $x, y: $y, openUntil: $openUntil) { errors } }",
        variables: { name: "Peets", x: 1.0, y: 2.0, openUntil: "9pm" }.to_json
      }, headers: auth_headers

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns a variable coercion error instead of executing the mutation when openUntil is omitted" do
      post "/graphql", params: {
        query: "mutation($name: String!, $x: Float!, $y: Float!, $address: String!) { " \
          "createCoffeeShop(name: $name, x: $x, y: $y, address: $address) { errors } }",
        variables: { name: "Peets", x: 1.0, y: 2.0, address: "123 Main St" }.to_json
      }, headers: auth_headers

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns validation errors and creates nothing when name is blank" do
      post_graphql(create_mutation, variables: { name: "", x: 1.0, y: 2.0, address: "123 Main St", openUntil: "9pm" })

      expect(response.parsed_body.dig("data", "createCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to include("Name can't be blank")
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns an error and creates nothing when openUntil is an empty string" do
      post_graphql(create_mutation, variables: {
        name: "Test3", x: 1.0, y: 2.0, address: "123 Main St", openUntil: ""
      })

      expect(response.parsed_body.dig("data", "createCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Open until can't be blank")
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns an error and creates nothing when address is a whitespace-only string" do
      post_graphql(create_mutation, variables: {
        name: "Test3", x: 1.0, y: 2.0, address: "   ", openUntil: "9pm"
      })

      expect(response.parsed_body.dig("data", "createCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Address can't be blank")
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns both errors when address and openUntil are both blank" do
      post_graphql(create_mutation, variables: { name: "Test3", x: 1.0, y: 2.0, address: "", openUntil: "" })

      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Address can't be blank; Open until can't be blank")
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns a variable coercion error instead of executing the mutation when x is not a number" do
      post_graphql(create_mutation, variables: {
        name: "Starbucks", x: "not-a-number", y: 2.0, address: "123 Main St", openUntil: "9pm"
      })

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns a user-friendly duplicate error, not one that leaks the internal slug concept" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)

      post_graphql(create_mutation, variables: {
        name: "Starbucks", x: 1.0, y: 2.0, address: "123 Main St", openUntil: "9pm"
      })

      expect(response.parsed_body.dig("data", "createCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to eq(CoffeeShop::DUPLICATE_ERROR_MESSAGE)
      expect(CoffeeShop.count).to eq(1)
    end

    it "returns an error instead of executing the mutation when the required x argument is omitted" do
      post "/graphql", params: {
        query: "mutation($name: String!, $y: Float!, $address: String!, $openUntil: String!) { " \
          "createCoffeeShop(name: $name, y: $y, address: $address, openUntil: $openUntil) { errors } }",
        variables: { name: "Starbucks", y: 2.0, address: "123 Main St", openUntil: "9pm" }.to_json
      }, headers: auth_headers

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
    end
  end

  describe "updateCoffeeShop" do
    def update_mutation
      <<~GRAPHQL
        mutation($id: ID!, $name: String, $x: Float, $y: Float, $address: String, $openUntil: String) {
          updateCoffeeShop(id: $id, name: $name, x: $x, y: $y, address: $address, openUntil: $openUntil) {
            coffeeShop {
              name
              x
              y
              address
              openUntil
            }
            errors
          }
        }
      GRAPHQL
    end

    it "updates only the given attributes, leaving the rest unchanged" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0, address: "123 Main St")

      post_graphql(update_mutation, variables: { id: shop.id, name: "Starbucks Renamed" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["errors"]).to eq([])
      expect(payload["coffeeShop"]).to include("name" => "Starbucks Renamed", "x" => 1.0, "address" => "123 Main St")
      expect(shop.reload.name).to eq("Starbucks Renamed")
    end

    it "leaves address unchanged when explicitly passed null, rather than blanking it out" do
      shop = create(:coffee_shop, name: "Starbucks", address: "123 Main St")

      post_graphql(update_mutation, variables: { id: shop.id, name: "Renamed", address: nil })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to include("name" => "Renamed", "address" => "123 Main St")
      expect(shop.reload.address).to eq("123 Main St")
    end

    it "leaves openUntil unchanged when explicitly passed an empty string, rather than blanking it out" do
      shop = create(:coffee_shop, name: "Starbucks", open_until: "9pm")

      post_graphql(update_mutation, variables: { id: shop.id, openUntil: "" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to include("openUntil" => "9pm")
      expect(shop.reload.open_until).to eq("9pm")
    end

    it "still sets address to a non-blank value when one is given" do
      shop = create(:coffee_shop, name: "Starbucks", address: "123 Main St")

      post_graphql(update_mutation, variables: { id: shop.id, address: "456 Side St" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to include("address" => "456 Side St")
      expect(shop.reload.address).to eq("456 Side St")
    end

    it "updates a CSV-imported shop's name without needing to supply an address or openUntil it never had" do
      shop = create(:coffee_shop, name: "Starbucks", address: nil, open_until: nil)

      post_graphql(update_mutation, variables: { id: shop.id, name: "Renamed" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["errors"]).to eq([])
      expect(payload["coffeeShop"]).to include("name" => "Renamed", "address" => nil, "openUntil" => nil)
    end

    it "updates coordinates" do
      shop = create(:coffee_shop, coordinate_x: 1.0, coordinate_y: 2.0)

      post_graphql(update_mutation, variables: { id: shop.id, x: 5.0, y: 6.0 })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to include("x" => 5.0, "y" => 6.0)
      expect(shop.reload).to have_attributes(coordinate_x: 5.0, coordinate_y: 6.0)
    end

    it "returns an error and does not update when the id does not exist" do
      post_graphql(update_mutation, variables: { id: 0, name: "Anything" })

      expect(response.parsed_body.dig("data", "updateCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Coffee shop not found")
    end

    it "returns validation errors and does not persist an invalid update" do
      shop = create(:coffee_shop, name: "Starbucks")

      post_graphql(update_mutation, variables: { id: shop.id, name: "" })

      expect(response.parsed_body.dig("data", "updateCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to be_present
      expect(shop.reload.name).to eq("Starbucks")
    end

    it "returns a variable coercion error instead of executing the mutation when x is not a number" do
      shop = create(:coffee_shop)

      post_graphql(update_mutation, variables: { id: shop.id, x: "not-a-number" })

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
    end

    it "leaves the slug unchanged even when name and coordinates are updated" do
      shop = create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)
      original_slug = shop.slug

      post_graphql(update_mutation, variables: { id: shop.id, name: "Renamed", x: 9.0, y: 9.0 })

      expect(shop.reload.slug).to eq(original_slug)
    end
  end

  describe "deleteCoffeeShop" do
    def delete_mutation
      <<~GRAPHQL
        mutation($id: ID!) {
          deleteCoffeeShop(id: $id) {
            coffeeShop {
              name
            }
            errors
          }
        }
      GRAPHQL
    end

    it "deletes an existing coffee shop and returns it" do
      shop = create(:coffee_shop, name: "Starbucks")

      post_graphql(delete_mutation, variables: { id: shop.id })

      payload = response.parsed_body.dig("data", "deleteCoffeeShop")
      expect(payload["errors"]).to eq([])
      expect(payload["coffeeShop"]).to eq("name" => "Starbucks")
      expect(CoffeeShop.exists?(shop.id)).to be false
    end

    it "returns an error and deletes nothing when the id does not exist" do
      post_graphql(delete_mutation, variables: { id: 0 })

      expect(response.parsed_body.dig("data", "deleteCoffeeShop")).to be_nil
      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Coffee shop not found")
    end
  end

  describe "authentication" do
    # createCoffeeShop stands in for all three CRUD mutations here - they share the same
    # BaseMutation#authenticate! check, so one mutation's worth of token-validity coverage is enough;
    # the per-mutation describe blocks above already cover each one rejecting with no token at all.
    def create_mutation_graphql(headers:)
      post "/graphql", params: {
        query: "mutation($name: String!, $x: Float!, $y: Float!, $address: String!, $openUntil: String!) { " \
          "createCoffeeShop(name: $name, x: $x, y: $y, address: $address, openUntil: $openUntil) { errors } }",
        variables: { name: "Probe", x: 0, y: 0, address: "123 Main St", openUntil: "9pm" }.to_json
      }, headers: headers
    end

    it "rejects createCoffeeShop with no Authorization header" do
      create_mutation_graphql(headers: {})

      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Unauthorized")
      expect(response.parsed_body.dig("data", "createCoffeeShop")).to be_nil
      expect(CoffeeShop.count).to eq(0)
    end

    it "rejects updateCoffeeShop with no Authorization header" do
      shop = create(:coffee_shop, name: "Starbucks")

      post "/graphql", params: {
        query: "mutation($id: ID!, $name: String!) { updateCoffeeShop(id: $id, name: $name) { errors } }",
        variables: { id: shop.id, name: "Renamed" }.to_json
      }

      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Unauthorized")
      expect(shop.reload.name).to eq("Starbucks")
    end

    it "rejects deleteCoffeeShop with no Authorization header" do
      shop = create(:coffee_shop, name: "Starbucks")

      post "/graphql", params: {
        query: "mutation($id: ID!) { deleteCoffeeShop(id: $id) { errors } }",
        variables: { id: shop.id }.to_json
      }

      expect(response.parsed_body.dig("errors", 0, "message")).to eq("Unauthorized")
      expect(CoffeeShop.exists?(shop.id)).to be true
    end

    it "rejects a garbage token" do
      create_mutation_graphql(headers: { "Authorization" => "Bearer not-a-jwt" })

      expect(response.parsed_body["errors"]).to be_present
      expect(CoffeeShop.count).to eq(0)
    end

    it "rejects an expired access token" do
      token, = JwtEncoder.new(user: user, token_type: :access).call

      travel_to(Time.current + Auth::ACCESS_TOKEN_TTL + 1.second) do
        create_mutation_graphql(headers: { "Authorization" => "Bearer #{token}" })
      end

      expect(response.parsed_body["errors"]).to be_present
      expect(CoffeeShop.count).to eq(0)
    end

    it "rejects a refresh token presented where an access token is required" do
      refresh_token, = JwtEncoder.new(user: user, token_type: :refresh).call

      create_mutation_graphql(headers: { "Authorization" => "Bearer #{refresh_token}" })

      expect(response.parsed_body["errors"]).to be_present
      expect(CoffeeShop.count).to eq(0)
    end

    it "accepts a valid access token" do
      create_mutation_graphql(headers: auth_headers)

      expect(response.parsed_body["errors"]).to be_nil
      expect(CoffeeShop.count).to eq(1)
    end
  end
end
