class AddColumnsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :token, :string 
    add_column :users, :name,     :string
    add_column :users, :refresh_token, :string
    add_column :users, :expires_in, :timestamp
    add_index :users, [:uid, :provider, :token, :refresh_token], unique: true
  end
end
