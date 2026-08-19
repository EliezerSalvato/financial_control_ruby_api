class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_enum :transaction_kind, %w[income expense transfer_between_accounts]
    create_enum :transaction_payment_method, %w[pix debit credit_card ted doc deposit cash boleto]
    create_enum :transaction_recurrence_type, %w[one_time installment recurring]
    create_enum :transaction_status, %w[pending active completed canceled]

    create_table :transactions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.references :category, null: false, foreign_key: true, type: :uuid, index: true
      t.string :description, null: false
      t.enum :kind, enum_type: :transaction_kind, null: false
      t.enum :status, enum_type: :transaction_status, null: false, default: "pending"
      t.enum :payment_method, enum_type: :transaction_payment_method, null: true
      t.enum :recurrence_type, enum_type: :transaction_recurrence_type, null: false
      t.integer :installments_count
      t.date :ends_on

      t.timestamps
    end

    add_index :transactions, :description
    add_index :transactions, :kind
    add_index :transactions, :status
    add_index :transactions, :payment_method
    add_index :transactions, :recurrence_type

    add_check_constraint :transactions,
                         <<~SQL.squish,
                           (
                             (recurrence_type = 'one_time' AND installments_count IS NULL AND ends_on IS NULL)
                             OR (recurrence_type = 'installment' AND installments_count > 1 AND ends_on IS NOT NULL)
                             OR (recurrence_type = 'recurring' AND installments_count IS NULL)
                           )
                         SQL
                         name: "transactions_recurrence_type_consistency"
  end
end
