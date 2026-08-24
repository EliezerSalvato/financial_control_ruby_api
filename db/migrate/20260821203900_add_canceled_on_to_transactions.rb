class AddCanceledOnToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :canceled_on, :date

    add_check_constraint :transactions,
                         <<~SQL.squish,
                           (status = 'canceled'::transaction_status AND canceled_on IS NOT NULL)
                           OR (status <> 'canceled'::transaction_status AND canceled_on IS NULL)
                         SQL
                         name: "transactions_canceled_on_consistency"
  end
end
