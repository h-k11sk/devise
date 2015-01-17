class AddColumnToEventSeries < ActiveRecord::Migration
  def change
    add_column :event_series, :user_id, :integer
    add_column :event_series, :gcal_id, :string
    add_index :event_series, [:user_id, :gcal_id]
  end
end
