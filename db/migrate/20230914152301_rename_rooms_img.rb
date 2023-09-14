class RenameRoomsImg < ActiveRecord::Migration[6.1]
  def change
    rename_column :rooms, :img, :image
  end
end
