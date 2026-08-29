class AddOccurredOnIndexToTransactionSettlements < ActiveRecord::Migration[8.1]
  def change
    add_index :transaction_settlements, :occurred_on
  end
end
