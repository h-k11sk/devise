class AddColumnToEventSeries < ActiveRecord::Migration
  def change
    add_column :event_series, :user_id, :integer
    add_index :event_series, :user_id
  end
end
