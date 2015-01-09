class AddColumnToEvent < ActiveRecord::Migration
  def change
    add_column :events, :user_id, :integer
    add_column :events, :gcal_id, :string
    add_index :events, [:user_id, :gcal_id]
  end
end
