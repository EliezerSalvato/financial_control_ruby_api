SELECT credit_cards.id AS credit_card_id,
       credit_cards.default_payment_account_id AS payment_account_id,
       cycle.opening_date,
       cycle.closing_date,
       cycle.due_date,
       COALESCE(SUM(settlements.value), 0) AS total_value
  FROM credit_cards
 CROSS JOIN LATERAL credit_card_billing_cycle_dates(credit_cards.id, :month, :year) AS cycle
  LEFT JOIN transaction_settlements AS settlements
         ON settlements.occurred_on BETWEEN cycle.opening_date AND cycle.closing_date
        AND settlements.transaction_id IN (
              SELECT transaction_id
                FROM transaction_for_credit_cards
               WHERE credit_card_id = credit_cards.id
            )
        AND EXISTS (
              SELECT 1
                FROM transaction_settlement_for_credit_cards
               WHERE transaction_settlement_id = settlements.id
                 AND credit_card_invoice_settlement_id IS NULL
            )
 WHERE credit_cards.user_id = :user_id
   AND cycle.due_date <= :reference_date
   AND NOT EXISTS (
         SELECT 1
           FROM credit_card_invoice_settlements
          WHERE credit_card_id = credit_cards.id
            AND due_date = cycle.due_date
       )
 GROUP BY credit_cards.id, credit_cards.default_payment_account_id, cycle.opening_date, cycle.closing_date, cycle.due_date
HAVING COALESCE(SUM(settlements.value), 0) > 0
