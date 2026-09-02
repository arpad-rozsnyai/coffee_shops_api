class CreateCoffeeShops < ActiveRecord::Migration[8.1]
  def change
    create_table :coffee_shops do |t|
      t.string :name, null: false
      t.float :coordinate_x, null: false
      t.float :coordinate_y, null: false
      t.string :address
      t.string :open_until

      t.timestamps
    end
  end
end
