class AddCurrentAccessTokenJtiToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_access_token_jti, :string
  end
end
