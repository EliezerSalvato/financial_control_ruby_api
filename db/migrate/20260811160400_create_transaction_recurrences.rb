class CreateTransactionRecurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_recurrences, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: true, type: :uuid, index: false
      t.date :starts_on, null: false
      t.decimal :value, precision: 15, scale: 2, null: false
      t.virtual :month, type: :integer, as: "EXTRACT(MONTH FROM starts_on)::integer", stored: true, null: false
      t.virtual :year, type: :integer, as: "EXTRACT(YEAR FROM starts_on)::integer", stored: true, null: false

      t.timestamps
    end

    add_index :transaction_recurrences, %i[transaction_id month year], unique: true

    add_check_constraint :transaction_recurrences,
                         "value >= 0",
                         name: "transaction_recurrences_value_non_negative"
  end
end
