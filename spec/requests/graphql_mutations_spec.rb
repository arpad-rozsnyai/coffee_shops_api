require "rails_helper"

RSpec.describe "POST /graphql (mutations)", type: :request do
  def post_graphql(query, variables: {})
    post "/graphql", params: { query: query, variables: variables.to_json }
  end

  describe "createCoffeeShop" do
    def create_mutation
      <<~GRAPHQL
        mutation($name: String!, $x: Float!, $y: Float!, $address: String, $openUntil: String) {
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

    it "creates a coffee shop without optional address/openUntil" do
      post_graphql(create_mutation, variables: { name: "Peets", x: 1.0, y: 2.0 })

      payload = response.parsed_body.dig("data", "createCoffeeShop")
      expect(payload["errors"]).to eq([])
      expect(payload["coffeeShop"]).to include("name" => "Peets", "address" => nil, "openUntil" => nil)
    end

    it "returns validation errors and creates nothing when name is blank" do
      post_graphql(create_mutation, variables: { name: "", x: 1.0, y: 2.0 })

      payload = response.parsed_body.dig("data", "createCoffeeShop")
      expect(payload["coffeeShop"]).to be_nil
      expect(payload["errors"]).to be_present
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns a variable coercion error instead of executing the mutation when x is not a number" do
      post_graphql(create_mutation, variables: { name: "Starbucks", x: "not-a-number", y: 2.0 })

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
      expect(CoffeeShop.count).to eq(0)
    end

    it "returns a user-friendly duplicate error, not one that leaks the internal slug concept" do
      create(:coffee_shop, name: "Starbucks", coordinate_x: 1.0, coordinate_y: 2.0)

      post_graphql(create_mutation, variables: { name: "Starbucks", x: 1.0, y: 2.0 })

      payload = response.parsed_body.dig("data", "createCoffeeShop")
      expect(payload["coffeeShop"]).to be_nil
      expect(payload["errors"]).to eq([ CoffeeShop::DUPLICATE_ERROR_MESSAGE ])
      expect(CoffeeShop.count).to eq(1)
    end

    it "returns an error instead of executing the mutation when the required x argument is omitted" do
      post "/graphql", params: {
        query: "mutation($name: String!, $y: Float!) { createCoffeeShop(name: $name, y: $y) { errors } }",
        variables: { name: "Starbucks", y: 2.0 }.to_json
      }

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

    it "updates coordinates" do
      shop = create(:coffee_shop, coordinate_x: 1.0, coordinate_y: 2.0)

      post_graphql(update_mutation, variables: { id: shop.id, x: 5.0, y: 6.0 })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to include("x" => 5.0, "y" => 6.0)
      expect(shop.reload).to have_attributes(coordinate_x: 5.0, coordinate_y: 6.0)
    end

    it "returns an error and does not update when the id does not exist" do
      post_graphql(update_mutation, variables: { id: 0, name: "Anything" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to be_nil
      expect(payload["errors"]).to eq([ "Coffee shop not found" ])
    end

    it "returns validation errors and does not persist an invalid update" do
      shop = create(:coffee_shop, name: "Starbucks")

      post_graphql(update_mutation, variables: { id: shop.id, name: "" })

      payload = response.parsed_body.dig("data", "updateCoffeeShop")
      expect(payload["coffeeShop"]).to be_nil
      expect(payload["errors"]).to be_present
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

      payload = response.parsed_body.dig("data", "deleteCoffeeShop")
      expect(payload["coffeeShop"]).to be_nil
      expect(payload["errors"]).to eq([ "Coffee shop not found" ])
    end
  end
end
