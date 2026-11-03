class AddSlugToJerseys < ActiveRecord::Migration[8.1]
  def change
    add_column :jerseys, :slug, :string
    add_index :jerseys, :slug, unique: true
  end
end
