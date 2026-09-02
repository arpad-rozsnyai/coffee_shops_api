class AddSlugToCoffeeShops < ActiveRecord::Migration[8.1]
  # A migration-local snapshot of the slug algorithm, deliberately not calling into CoffeeShop
  # (app/models/coffee_shop.rb) — that class is free to change its slug logic later without rewriting
  # this historical backfill.
  class MigrationCoffeeShop < ActiveRecord::Base
    self.table_name = "coffee_shops"
  end

  def up
    add_column :coffee_shops, :slug, :string

    MigrationCoffeeShop.reset_column_information
    MigrationCoffeeShop.find_each do |shop|
      shop.update_column(:slug, generate_slug(shop.name, shop.coordinate_x, shop.coordinate_y))
    end

    change_column_null :coffee_shops, :slug, false
    remove_index :coffee_shops, name: "index_coffee_shops_on_name_and_coordinates"
    add_index :coffee_shops, :slug, unique: true
  end

  def down
    add_index :coffee_shops, [ :name, :coordinate_x, :coordinate_y ], unique: true,
                                                                        name: "index_coffee_shops_on_name_and_coordinates"
    remove_index :coffee_shops, :slug
    remove_column :coffee_shops, :slug
  end

  private

  def generate_slug(name, coordinate_x, coordinate_y)
    [ name, signed_component(coordinate_x), signed_component(coordinate_y) ].join("-").parameterize
  end

  def signed_component(value)
    value&.negative? ? "neg#{value.abs}" : value.to_s
  end
end
