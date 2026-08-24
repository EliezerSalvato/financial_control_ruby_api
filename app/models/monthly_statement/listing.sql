WITH credit_cards_with_billing_cycle_dates AS (
  SELECT credit_cards.id,
         credit_cards.name,
         credit_cards.network,
         billing_cycle_dates.opening_date,
         billing_cycle_dates.closing_date,
         billing_cycle_dates.due_date
    FROM credit_cards,
         credit_card_billing_cycle_dates(credit_cards.id, :month, :year) AS billing_cycle_dates
   WHERE credit_cards.user_id = :user_id
)
SELECT transactions.id,
       transactions.kind,
       transactions.description,
       transactions.recurrence_type,
       'credit_card' AS payment_method,
       credit_cards.id AS resource_id,
       credit_cards.name AS resource_name,
       credit_cards.network AS resource_brand,
       credit_cards.opening_date,
       credit_cards.closing_date,
       credit_cards.due_date,
       current_transaction_recurrences.value,
       first_transaction_recurrences.first_recurrence_on,
       first_transaction_recurrences.current_recurrence_on,
       current_transaction_recurrences.starts_on,
       transactions.ends_on,
       transactions.canceled_on
  FROM transactions
  JOIN transaction_for_credit_cards
    ON transaction_for_credit_cards.transaction_id = transactions.id
  JOIN credit_cards_with_billing_cycle_dates AS credit_cards
    ON credit_cards.id = transaction_for_credit_cards.credit_card_id
  JOIN LATERAL (
         SELECT transaction_recurrences.starts_on AS first_recurrence_on,
                monthly_occurrence_on(transaction_recurrences.starts_on, credit_cards.opening_date, credit_cards.closing_date) AS current_recurrence_on
           FROM transaction_recurrences
          WHERE transaction_recurrences.transaction_id = transactions.id
       ORDER BY transaction_recurrences.starts_on
          LIMIT 1
       ) AS first_transaction_recurrences ON true
  JOIN LATERAL (
         SELECT transaction_recurrences.value,
                transaction_recurrences.starts_on
           FROM transaction_recurrences
          WHERE transaction_recurrences.transaction_id = transactions.id
            AND transaction_recurrences.starts_on <= credit_cards.closing_date
       ORDER BY transaction_recurrences.starts_on DESC
          LIMIT 1
       ) AS current_transaction_recurrences ON true
 WHERE transactions.user_id = :user_id
   AND CASE transactions.recurrence_type
         WHEN 'one_time' THEN current_transaction_recurrences.starts_on >= credit_cards.opening_date
         ELSE (
                (
                  transactions.ends_on IS NULL OR
                  first_transaction_recurrences.current_recurrence_on <= transactions.ends_on OR
                  (
                    first_transaction_recurrences.current_recurrence_on = credit_cards.opening_date AND
                    first_transaction_recurrences.current_recurrence_on = transactions.ends_on + 1 AND
                    EXTRACT(DAY FROM first_transaction_recurrences.first_recurrence_on) <> EXTRACT(DAY FROM first_transaction_recurrences.current_recurrence_on)
                  )
                ) AND
                first_transaction_recurrences.current_recurrence_on >= first_transaction_recurrences.first_recurrence_on AND
                first_transaction_recurrences.current_recurrence_on BETWEEN credit_cards.opening_date AND credit_cards.closing_date
              )
       END
   AND (transactions.canceled_on IS NULL OR first_transaction_recurrences.current_recurrence_on <= transactions.canceled_on)
UNION ALL
SELECT transactions.id,
       transactions.kind,
       transactions.description,
       transactions.recurrence_type,
       'account' AS payment_method,
       accounts.id AS resource_id,
       accounts.name AS resource_name,
       accounts.resource_brand,
       accounts.opening_date,
       accounts.closing_date,
       NULL AS due_date,
       current_transaction_recurrences.value,
       first_transaction_recurrences.first_recurrence_on,
       first_transaction_recurrences.current_recurrence_on,
       current_transaction_recurrences.starts_on,
       transactions.ends_on,
       transactions.canceled_on
  FROM transactions
  JOIN transaction_for_accounts
    ON transaction_for_accounts.transaction_id = transactions.id
  JOIN LATERAL (
         SELECT accounts.*,
                COALESCE(institutions.logo_key, accounts.color) AS resource_brand,
                make_date(:year, :month, 1) AS opening_date,
                make_date_clamped(:year, :month, 31) AS closing_date
           FROM accounts
      LEFT JOIN institutions
             ON institutions.id = accounts.institution_id
          WHERE accounts.id = transaction_for_accounts.account_id
       ) AS accounts ON true
  JOIN LATERAL (
         SELECT transaction_recurrences.starts_on AS first_recurrence_on,
                monthly_occurrence_on(transaction_recurrences.starts_on, accounts.opening_date, accounts.closing_date) AS current_recurrence_on
           FROM transaction_recurrences
          WHERE transaction_recurrences.transaction_id = transactions.id
       ORDER BY transaction_recurrences.starts_on
          LIMIT 1
       ) AS first_transaction_recurrences ON true
  JOIN LATERAL (
         SELECT transaction_recurrences.value,
                transaction_recurrences.starts_on
           FROM transaction_recurrences
          WHERE transaction_recurrences.transaction_id = transactions.id
            AND transaction_recurrences.starts_on <= accounts.closing_date
       ORDER BY transaction_recurrences.starts_on DESC
          LIMIT 1
       ) AS current_transaction_recurrences ON true
 WHERE transactions.user_id = :user_id
   AND CASE transactions.recurrence_type
         WHEN 'one_time' THEN current_transaction_recurrences.starts_on >= accounts.opening_date
         ELSE (
                (
                  transactions.ends_on IS NULL OR
                  first_transaction_recurrences.current_recurrence_on <= transactions.ends_on OR
                  (
                    first_transaction_recurrences.current_recurrence_on = accounts.opening_date AND
                    first_transaction_recurrences.current_recurrence_on = transactions.ends_on + 1 AND
                    EXTRACT(DAY FROM first_transaction_recurrences.first_recurrence_on) <> EXTRACT(DAY FROM first_transaction_recurrences.current_recurrence_on)
                  )
                ) AND
                first_transaction_recurrences.current_recurrence_on >= first_transaction_recurrences.first_recurrence_on AND
                first_transaction_recurrences.current_recurrence_on BETWEEN accounts.opening_date AND accounts.closing_date
              )
       END
   AND (transactions.canceled_on IS NULL OR first_transaction_recurrences.current_recurrence_on <= transactions.canceled_on)
