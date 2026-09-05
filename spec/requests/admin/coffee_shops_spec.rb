require "rails_helper"

RSpec.describe "Admin::CoffeeShops", type: :request do
  describe "authentication" do
    it "redirects anonymous visitors to the sign-in page" do
      get "/admin/coffee_shops"

      expect(response).to redirect_to("/admin/login")
    end
  end

  describe "GET /admin/coffee_shops" do
    before { sign_in create(:user) }

    it "lists coffee shops" do
      create(:coffee_shop, name: "Blue Bottle")

      get "/admin/coffee_shops"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blue Bottle")
    end

    it "filters by name" do
      create(:coffee_shop, name: "Blue Bottle")
      create(:coffee_shop, name: "Starbucks")

      get "/admin/coffee_shops", params: { q: { name_cont: "Blue" } }

      expect(response.body).to include("Blue Bottle")
      expect(response.body).not_to include("Starbucks")
    end

    it "filters by id" do
      target = create(:coffee_shop, name: "Blue Bottle")
      create(:coffee_shop, name: "Starbucks")

      get "/admin/coffee_shops", params: { q: { id_eq: target.id } }

      expect(response.body).to include("Blue Bottle")
      expect(response.body).not_to include("Starbucks")
    end
  end

  describe "POST /admin/coffee_shops" do
    before { sign_in create(:user) }

    it "creates a coffee shop when all fields are present" do
      expect {
        post "/admin/coffee_shops", params: {
          coffee_shop: { name: "Blue Bottle", x: "1.0", y: "2.0", address: "123 Main St", open_until: "9pm" }
        }
      }.to change(CoffeeShop, :count).by(1)

      expect(response).to redirect_to("/admin/coffee_shops")
    end

    it "rejects a blank address without creating a record" do
      expect {
        post "/admin/coffee_shops", params: {
          coffee_shop: { name: "Blue Bottle", x: "1.0", y: "2.0", address: "", open_until: "9pm" }
        }
      }.not_to change(CoffeeShop, :count)

      expect(response).not_to be_redirect
      expect(response.body).to include("can&#39;t be blank")
    end

    it "rejects a blank open_until without creating a record" do
      expect {
        post "/admin/coffee_shops", params: {
          coffee_shop: { name: "Blue Bottle", x: "1.0", y: "2.0", address: "123 Main St", open_until: "" }
        }
      }.not_to change(CoffeeShop, :count)

      expect(response).not_to be_redirect
      expect(response.body).to include("can&#39;t be blank")
    end
  end

  describe "PATCH /admin/coffee_shops/:id" do
    before { sign_in create(:user) }

    it "updates a coffee shop when all fields are present" do
      coffee_shop = create(:coffee_shop, name: "Blue Bottle")

      patch "/admin/coffee_shops/#{coffee_shop.id}", params: {
        coffee_shop: { name: "Blue Bottle 2", x: "1.0", y: "2.0", address: "123 Main St", open_until: "9pm" }
      }

      expect(response).to redirect_to("/admin/coffee_shops")
      expect(coffee_shop.reload.name).to eq("Blue Bottle 2")
    end

    it "rejects a blank address without touching the existing record" do
      coffee_shop = create(:coffee_shop, name: "Blue Bottle", address: "Original Address")

      patch "/admin/coffee_shops/#{coffee_shop.id}", params: {
        coffee_shop: { name: "Blue Bottle 2", x: "1.0", y: "2.0", address: "", open_until: "9pm" }
      }

      expect(response).not_to be_redirect
      expect(coffee_shop.reload.address).to eq("Original Address")
      expect(coffee_shop.reload.name).to eq("Blue Bottle")
    end
  end

  describe "DELETE /admin/coffee_shops/:id" do
    before { sign_in create(:user) }

    it "destroys the coffee shop" do
      coffee_shop = create(:coffee_shop)

      expect {
        delete "/admin/coffee_shops/#{coffee_shop.id}"
      }.to change(CoffeeShop, :count).by(-1)
    end
  end
end
