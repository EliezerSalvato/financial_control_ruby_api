class AddAllowNegativeFlagsToAccountsAndCreditCards < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :allow_negative_balance, :boolean, null: false, default: false
    add_column :credit_cards, :allow_negative_available_limit, :boolean, null: false, default: false
  end
end
