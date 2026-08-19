class CreateTransactionTags < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_tags, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: true, type: :uuid, index: false
      t.references :tag, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps
    end

    add_index :transaction_tags, %i[transaction_id tag_id], unique: true
  end
end
