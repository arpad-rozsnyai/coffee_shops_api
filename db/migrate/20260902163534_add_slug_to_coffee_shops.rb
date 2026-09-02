class AddSlugToCoffeeShops < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationCoffeeShop < ActiveRecord::Base
    self.table_name = "coffee_shops"
  end

  def up
    add_column :coffee_shops, :slug, :string

    MigrationCoffeeShop.reset_column_information
    backfill_slugs

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

  def backfill_slugs
    MigrationCoffeeShop.in_batches(of: 1000) do |batch|
      rows = batch.pluck(:id, :name, :coordinate_x, :coordinate_y, :created_at, :updated_at).map do |id, name, coordinate_x, coordinate_y, created_at, updated_at|
        { id: id, name: name, coordinate_x: coordinate_x, coordinate_y: coordinate_y,
          created_at: created_at, updated_at: updated_at, slug: generate_slug(name, coordinate_x, coordinate_y) }
      end

      MigrationCoffeeShop.upsert_all(rows, update_only: [ :slug ], record_timestamps: false) if rows.any?
    end
  end

  def generate_slug(name, coordinate_x, coordinate_y)
    [ name, signed_component(coordinate_x), signed_component(coordinate_y) ].join("-").parameterize
  end

  def signed_component(value)
    value&.negative? ? "neg#{value.abs}" : value.to_s
  end
end
