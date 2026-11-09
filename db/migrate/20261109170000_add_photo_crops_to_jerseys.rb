class AddPhotoCropsToJerseys < ActiveRecord::Migration[8.1]
  def change
    # How each photo is framed, keyed by blob id: { "12" => { "x" => 0.5, "y" => 0.4, "zoom" => 1.3 } }.
    # The original uploads are never altered, so a photo can always be re-cropped.
    add_column :jerseys, :photo_crops, :jsonb, default: {}, null: false
  end
end
