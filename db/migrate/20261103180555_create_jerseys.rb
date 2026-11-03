class CreateJerseys < ActiveRecord::Migration[8.1]
  def change
    create_table :jerseys do |t|
      t.string :title
      t.string :club
      t.string :season
      t.string :size
      t.decimal :price, precision: 8, scale: 2
      t.text :description

      t.timestamps
    end
  end
end
