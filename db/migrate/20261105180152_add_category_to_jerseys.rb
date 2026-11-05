class AddCategoryToJerseys < ActiveRecord::Migration[8.1]
  def change
    add_reference :jerseys, :category, null: true, foreign_key: true
  end
end
