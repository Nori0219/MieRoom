class RenameEntryrecods < ActiveRecord::Migration[6.1]
  def change
    rename_table :entryrecords, :entry_records
  end
end
