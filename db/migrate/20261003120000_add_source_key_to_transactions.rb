class AddSourceKeyToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :source_key, :string

    add_index :transactions, %i[user_id source_key],
              unique: true,
              where: "source_key IS NOT NULL",
              name: "index_transactions_on_user_id_and_source_key"
  end
end
