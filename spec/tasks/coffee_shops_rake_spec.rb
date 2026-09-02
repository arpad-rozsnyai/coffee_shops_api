require "rails_helper"
require "rake"

RSpec.describe "coffee_shops:import rake task" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("coffee_shops:import")
  end

  let(:task) { Rake::Task["coffee_shops:import"] }

  before { task.reenable }

  it "imports coffee shops from the CSV feed into the database" do
    stub_request(:get, CoffeeShops.csv_url).to_return(status: 200, body: "Starbucks,47.6,-122.4\n")

    expect { task.invoke }.to change(CoffeeShop, :count).by(1)
  end

  it "skips shops that were already imported on a rerun" do
    create(:coffee_shop, name: "Starbucks", coordinate_x: 47.6, coordinate_y: -122.4)
    stub_request(:get, CoffeeShops.csv_url).to_return(status: 200, body: "Starbucks,47.6,-122.4\n")

    expect { task.invoke }.not_to change(CoffeeShop, :count)
  end

  it "prints the number of shops imported" do
    stub_request(:get, CoffeeShops.csv_url).to_return(status: 200, body: "Starbucks,47.6,-122.4\n")

    expect { task.invoke }.to output(/Imported 1 coffee shop\(s\)/).to_stdout
  end

  it "prints each shop's name, coordinates, and import verdict" do
    stub_request(:get, CoffeeShops.csv_url).to_return(status: 200, body: "Starbucks,47.6,-122.4\n")

    expect { task.invoke }.to output(/Starbucks \(47\.6, -122\.4\): imported/).to_stdout
  end

  it "marks an already-imported shop as a duplicate rather than reimporting it" do
    create(:coffee_shop, name: "Starbucks", coordinate_x: 47.6, coordinate_y: -122.4)
    stub_request(:get, CoffeeShops.csv_url).to_return(status: 200, body: "Starbucks,47.6,-122.4\n")

    expect { task.invoke }.to output(/Starbucks \(47\.6, -122\.4\): duplicate, skipped/).to_stdout
  end

  it "exits with an error and leaves the database untouched when the remote source fails" do
    create(:coffee_shop, name: "Stays")
    stub_request(:get, CoffeeShops.csv_url).to_timeout

    expect { task.invoke }.to raise_error(SystemExit)
    expect(CoffeeShop.pluck(:name)).to eq([ "Stays" ])
  end
end
