class UpdateCreditCardsAvailableLimitCheckConstraint < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :credit_cards,
                            "available_limit BETWEEN 0 AND total_limit",
                            name: "credit_cards_available_limit_within_total"

    add_check_constraint :credit_cards,
                         "(allow_negative_available_limit OR available_limit >= 0) AND available_limit <= total_limit",
                         name: "credit_cards_available_limit_within_total"
  end
end
