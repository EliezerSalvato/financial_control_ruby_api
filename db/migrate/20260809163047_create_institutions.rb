class CreateInstitutions < ActiveRecord::Migration[8.1]
  def change
    create_table :institutions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.string :name, null: false
      t.string :logo_key, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :institutions, "user_id, LOWER(name)", unique: true, name: "index_institutions_on_user_id_and_lower_name"
    add_index :institutions, %i[user_id active]
  end
end
