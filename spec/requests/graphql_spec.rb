require "rails_helper"

RSpec.describe "POST /graphql", type: :request do
  def post_graphql(query, variables: {})
    post "/graphql", params: { query: query, variables: variables.to_json }
  end

  describe "coffeeShops" do
    it "returns all persisted coffee shops" do
      create(:coffee_shop, name: "Near", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "Far", coordinate_x: 10, coordinate_y: 0)

      post_graphql(<<~GRAPHQL)
        query {
          coffeeShops {
            name
            x
            y
          }
        }
      GRAPHQL

      expect(response).to have_http_status(:ok)
      shops = response.parsed_body.dig("data", "coffeeShops")
      expect(shops.map { |s| s["name"] }).to contain_exactly("Near", "Far")
    end

    it "returns an empty array when no coffee shops are persisted" do
      post_graphql(<<~GRAPHQL)
        query {
          coffeeShops {
            name
          }
        }
      GRAPHQL

      expect(response.parsed_body.dig("data", "coffeeShops")).to eq([])
    end

    it "defaults to a limit of #{Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT} results when limit is not given" do
      expect(CoffeeShop).to receive(:limit).with(Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT).and_call_original

      post_graphql(<<~GRAPHQL)
        query {
          coffeeShops {
            name
          }
        }
      GRAPHQL

      expect(response).to have_http_status(:ok)
    end

    it "filters by a case-insensitive partial match against name" do
      create(:coffee_shop, name: "Blue Bottle Coffee")
      create(:coffee_shop, name: "Starbucks")

      post_graphql(<<~GRAPHQL, variables: { name: "blue" })
        query($name: String) {
          coffeeShops(name: $name) {
            name
          }
        }
      GRAPHQL

      expect(response).to have_http_status(:ok)
      shops = response.parsed_body.dig("data", "coffeeShops")
      expect(shops.map { |s| s["name"] }).to contain_exactly("Blue Bottle Coffee")
    end

    it "returns an empty array when the name filter matches nothing" do
      create(:coffee_shop, name: "Starbucks")

      post_graphql(<<~GRAPHQL, variables: { name: "nonexistent" })
        query($name: String) {
          coffeeShops(name: $name) {
            name
          }
        }
      GRAPHQL

      expect(response.parsed_body.dig("data", "coffeeShops")).to eq([])
    end

    it "treats % and _ in the name filter as literal characters, not SQL wildcards" do
      create(:coffee_shop, name: "100% Coffee")
      create(:coffee_shop, name: "AnyCoffee")

      post_graphql(<<~GRAPHQL, variables: { name: "100%" })
        query($name: String) {
          coffeeShops(name: $name) {
            name
          }
        }
      GRAPHQL

      shops = response.parsed_body.dig("data", "coffeeShops")
      expect(shops.map { |s| s["name"] }).to contain_exactly("100% Coffee")
    end

    it "defaults filtered results to the default limit when limit is not given" do
      (Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT + 2).times { |n| create(:coffee_shop, name: "Filtered #{n}") }

      post_graphql(<<~GRAPHQL, variables: { name: "Filtered" })
        query($name: String) {
          coffeeShops(name: $name) {
            name
          }
        }
      GRAPHQL

      shops = response.parsed_body.dig("data", "coffeeShops")
      expect(shops.size).to eq(Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT)
    end

    describe "limit argument" do
      it "returns at most the requested number of results when a valid positive limit is given" do
        4.times { |n| create(:coffee_shop, name: "Shop #{n}") }

        post_graphql(<<~GRAPHQL, variables: { limit: 2 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response).to have_http_status(:ok)
        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(2)
      end

      it "combines the limit argument with the name filter" do
        3.times { |n| create(:coffee_shop, name: "Filtered #{n}") }
        create(:coffee_shop, name: "Unrelated")

        post_graphql(<<~GRAPHQL, variables: { name: "Filtered", limit: 1 })
          query($name: String, $limit: Int) {
            coffeeShops(name: $name, limit: $limit) {
              name
            }
          }
        GRAPHQL

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(1)
      end

      it "falls back to the default limit when limit is negative" do
        expect(CoffeeShop).to receive(:limit).with(Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT).and_call_original

        post_graphql(<<~GRAPHQL, variables: { limit: -1 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["errors"]).to be_nil
      end

      it "falls back to the default limit when limit is zero" do
        expect(CoffeeShop).to receive(:limit).with(Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT).and_call_original

        post_graphql(<<~GRAPHQL, variables: { limit: 0 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["errors"]).to be_nil
      end

      it "falls back to the default limit when limit is explicitly null" do
        expect(CoffeeShop).to receive(:limit).with(Types::QueryType::DEFAULT_COFFEE_SHOPS_LIMIT).and_call_original

        post_graphql(<<~GRAPHQL, variables: { limit: nil })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["errors"]).to be_nil
      end

      it "returns a variable coercion error instead of executing the query when limit is a string" do
        post_graphql(<<~GRAPHQL, variables: { limit: "2" })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response.parsed_body["errors"]).to be_present
        expect(response.parsed_body["data"]).to be_nil
      end

      it "rejects a SQL-injection-like string limit as a coercion error without touching the database" do
        create(:coffee_shop, name: "Survivor")

        post_graphql(<<~GRAPHQL, variables: { limit: "1; DROP TABLE coffee_shops;" })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response.parsed_body["errors"]).to be_present
        expect(response.parsed_body["data"]).to be_nil
        expect(CoffeeShop.count).to eq(1)
      end

      it "returns a variable coercion error instead of executing the query when limit is a float" do
        post_graphql(<<~GRAPHQL, variables: { limit: 1.5 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
            }
          }
        GRAPHQL

        expect(response.parsed_body["errors"]).to be_present
        expect(response.parsed_body["data"]).to be_nil
      end
    end

    describe "highlighted" do
      def highlighted_query_graphql
        <<~GRAPHQL
          query {
            coffeeShops {
              name
              highlighted
            }
          }
        GRAPHQL
      end

      it "flags the first three results as highlighted and leaves the rest unhighlighted" do
        5.times { |n| create(:coffee_shop, name: "Shop #{('A'.ord + n).chr}") }

        post_graphql(highlighted_query_graphql)

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(5)
        expect(shops.first(3).map { |s| s["highlighted"] }).to all(be true)
        expect(shops.last(2).map { |s| s["highlighted"] }).to all(be false)
      end

      it "flags all results as highlighted when there are fewer than three" do
        create(:coffee_shop, name: "Only One")

        post_graphql(highlighted_query_graphql)

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(1)
        expect(shops.first["highlighted"]).to eq(true)
      end

      it "flags all results as highlighted when there are exactly three" do
        3.times { |n| create(:coffee_shop, name: "Shop #{n}") }

        post_graphql(highlighted_query_graphql)

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(3)
        expect(shops.map { |s| s["highlighted"] }).to all(be true)
      end

      it "returns an empty array, with no error, when there are no results to highlight" do
        post_graphql(highlighted_query_graphql)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "coffeeShops")).to eq([])
      end

      it "still only highlights the first three results when the limit argument raises the cap above three" do
        5.times { |n| create(:coffee_shop, name: "Shop #{n}") }

        post_graphql(<<~GRAPHQL, variables: { limit: 5 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
              highlighted
            }
          }
        GRAPHQL

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(5)
        expect(shops.first(3).map { |s| s["highlighted"] }).to all(be true)
        expect(shops.last(2).map { |s| s["highlighted"] }).to all(be false)
      end

      it "highlights all results when the limit argument caps them below three" do
        5.times { |n| create(:coffee_shop, name: "Shop #{n}") }

        post_graphql(<<~GRAPHQL, variables: { limit: 2 })
          query($limit: Int) {
            coffeeShops(limit: $limit) {
              name
              highlighted
            }
          }
        GRAPHQL

        shops = response.parsed_body.dig("data", "coffeeShops")
        expect(shops.size).to eq(2)
        expect(shops.map { |s| s["highlighted"] }).to all(be true)
      end

      it "is false for coffeeShop(id:), which is outside the search field this flag applies to" do
        shop = create(:coffee_shop, name: "Only")

        post_graphql(<<~GRAPHQL, variables: { id: shop.id })
          query($id: ID!) {
            coffeeShop(id: $id) {
              highlighted
            }
          }
        GRAPHQL

        expect(response.parsed_body.dig("data", "coffeeShop", "highlighted")).to eq(false)
      end

      it "is false for the shop nested inside nearestCoffeeShops, which is outside the search field this flag applies to" do
        create(:coffee_shop, name: "Only", coordinate_x: 1, coordinate_y: 0)

        post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
          query($x: Float!, $y: Float!) {
            nearestCoffeeShops(x: $x, y: $y) {
              coffeeShop { highlighted }
            }
          }
        GRAPHQL

        results = response.parsed_body.dig("data", "nearestCoffeeShops")
        expect(results.first["coffeeShop"]["highlighted"]).to eq(false)
      end
    end

    it "returns all coffee shops when name is not given" do
      create(:coffee_shop, name: "Near")
      create(:coffee_shop, name: "Far")

      post_graphql(<<~GRAPHQL)
        query {
          coffeeShops {
            name
          }
        }
      GRAPHQL

      shops = response.parsed_body.dig("data", "coffeeShops")
      expect(shops.map { |s| s["name"] }).to contain_exactly("Near", "Far")
    end

    it "works with a query sent with no variables key at all" do
      post "/graphql", params: { query: "query { coffeeShops { name } }" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "coffeeShops")).to eq([])
    end

    it "works with variables sent as a nested JSON object rather than a JSON-encoded string" do
      shop = create(:coffee_shop, name: "Only")

      post "/graphql",
        params: { query: "query($id: ID!) { coffeeShop(id: $id) { name } }", variables: { id: shop.id } }.to_json,
        headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "coffeeShop", "name")).to eq("Only")
    end
  end

  describe "coffeeShop(id:)" do
    it "returns a single coffee shop by id" do
      shop = create(:coffee_shop, name: "Only")

      post_graphql(<<~GRAPHQL, variables: { id: shop.id })
        query($id: ID!) {
          coffeeShop(id: $id) {
            name
          }
        }
      GRAPHQL

      expect(response.parsed_body.dig("data", "coffeeShop", "name")).to eq("Only")
    end

    it "returns null for an id that does not exist" do
      post_graphql(<<~GRAPHQL, variables: { id: "0" })
        query($id: ID!) {
          coffeeShop(id: $id) {
            name
          }
        }
      GRAPHQL

      expect(response.parsed_body.dig("data", "coffeeShop")).to be_nil
    end
  end

  describe "nearestCoffeeShops" do
    it "returns the three nearest persisted shops ordered nearest to farthest, with distance" do
      create(:coffee_shop, name: "Far", coordinate_x: 10, coordinate_y: 0)
      create(:coffee_shop, name: "Near", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "Farthest", coordinate_x: 20, coordinate_y: 0)
      create(:coffee_shop, name: "Mid", coordinate_x: 3, coordinate_y: 0)

      post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            distance
            coffeeShop {
              name
            }
          }
        }
      GRAPHQL

      results = response.parsed_body.dig("data", "nearestCoffeeShops")
      expect(results.map { |r| r["coffeeShop"]["name"] }).to eq(%w[Near Mid Far])
      expect(results.first["distance"]).to eq(1.0)
    end

    it "returns a variable coercion error when x or y is missing" do
      post_graphql(<<~GRAPHQL, variables: { x: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            distance
          }
        }
      GRAPHQL

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
    end

    it "returns a variable coercion error when x is not a number" do
      post_graphql(<<~GRAPHQL, variables: { x: "not-a-number", y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            distance
          }
        }
      GRAPHQL

      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["data"]).to be_nil
    end

    it "rounds distance to four decimal places" do
      create(:coffee_shop, name: "Diagonal", coordinate_x: 1, coordinate_y: 1)

      post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            distance
          }
        }
      GRAPHQL

      results = response.parsed_body.dig("data", "nearestCoffeeShops")
      expect(results.first["distance"]).to eq(1.4142)
    end

    it "returns fewer than three results when fewer shops exist" do
      create(:coffee_shop, name: "Only", coordinate_x: 1, coordinate_y: 0)

      post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            coffeeShop { name }
          }
        }
      GRAPHQL

      results = response.parsed_body.dig("data", "nearestCoffeeShops")
      expect(results.size).to eq(1)
    end

    it "returns an empty array of nearest shops when no coffee shops are persisted" do
      post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            coffeeShop { name }
          }
        }
      GRAPHQL

      expect(response.parsed_body.dig("data", "nearestCoffeeShops")).to eq([])
    end

    it "breaks exact distance ties deterministically by shop name" do
      create(:coffee_shop, name: "B Shop", coordinate_x: 1, coordinate_y: 0)
      create(:coffee_shop, name: "A Shop", coordinate_x: 0, coordinate_y: 1)

      post_graphql(<<~GRAPHQL, variables: { x: 0, y: 0 })
        query($x: Float!, $y: Float!) {
          nearestCoffeeShops(x: $x, y: $y) {
            coffeeShop { name }
          }
        }
      GRAPHQL

      results = response.parsed_body.dig("data", "nearestCoffeeShops")
      expect(results.map { |r| r["coffeeShop"]["name"] }).to eq([ "A Shop", "B Shop" ])
    end
  end

  describe "malformed requests" do
    it "returns a query error instead of a 500 when the query param is missing" do
      post "/graphql", params: {}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns a query error instead of a 500 when the query is syntactically invalid" do
      post "/graphql", params: { query: "{ this is not valid graphql" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["errors"]).to be_present
    end
  end
end
