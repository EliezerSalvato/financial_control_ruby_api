class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.string :name, null: false
      t.string :color, null: false, limit: 9
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :tags, "user_id, LOWER(name)", unique: true, name: "index_tags_on_user_id_and_lower_name"
    add_index :tags, %i[user_id active]
  end
end
