class CreateEntryRecods < ActiveRecord::Migration[6.1]
  def change
    create_table :entryrecords do |t|
      t.integer :user_id
      t.integer :room_id
      t.datetime :entry_time
      t.datetime :exit_time
      t.timestamps null: false
    end
  end
end
