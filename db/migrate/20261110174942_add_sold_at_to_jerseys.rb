class AddSoldAtToJerseys < ActiveRecord::Migration[8.1]
  def change
    add_column :jerseys, :sold_at, :datetime
    add_index :jerseys, :sold_at
  end
end
