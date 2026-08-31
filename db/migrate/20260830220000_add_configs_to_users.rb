class AddConfigsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :configs, :jsonb, null: false, default: {}
  end
end
