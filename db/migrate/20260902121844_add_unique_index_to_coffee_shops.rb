class AddUniqueIndexToCoffeeShops < ActiveRecord::Migration[8.1]
  def change
    add_index :coffee_shops, [ :name, :coordinate_x, :coordinate_y ], unique: true,
                                                                       name: "index_coffee_shops_on_name_and_coordinates"
  end
end
