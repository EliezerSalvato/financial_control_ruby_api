SELECT transactions.id,
       transactions.kind,
       transactions.description,
       transactions.recurrence_type,
       source_accounts.id AS source_account_id,
       source_accounts.name AS source_account_name,
       source_accounts.resource_brand AS source_account_brand,
       destination_accounts.id AS destination_account_id,
       destination_accounts.name AS destination_account_name,
       destination_accounts.resource_brand AS destination_account_brand,
       period.opening_date,
       period.closing_date,
       current_transaction_recurrences.value,
       first_transaction_recurrences.first_recurrence_on,
       first_transaction_recurrences.current_recurrence_on,
       current_transaction_recurrences.starts_on,
       transactions.ends_on,
       transactions.canceled_on
  FROM transactions
  JOIN transaction_for_transfer_between_accounts
    ON transaction_for_transfer_between_accounts.transaction_id = transactions.id
  JOIN LATERAL (
         SELECT make_date(:year, :month, 1) AS opening_date,
                make_date_clamped(:year, :month, 31) AS closing_date
       ) AS period ON true
  JOIN LATERAL (
         SELECT accounts.id,
                accounts.name,
                COALESCE(institutions.logo_key, accounts.color) AS resource_brand
           FROM accounts
      LEFT JOIN institutions
             ON institutions.id = accounts.institution_id
          WHERE accounts.id = transaction_for_transfer_between_accounts.source_account_id
       ) AS source_accounts ON true
  JOIN LATERAL (
         SELECT accounts.id,
                accounts.name,
                COALESCE(institutions.logo_key, accounts.color) AS resource_brand
           FROM accounts
      LEFT JOIN institutions
             ON institutions.id = accounts.institution_id
          WHERE accounts.id = transaction_for_transfer_between_accounts.destination_account_id
       ) AS destination_accounts ON true
  JOIN LATERAL (
         SELECT transaction_recurrences.starts_on AS first_recurrence_on,
                monthly_occurrence_on(transaction_recurrences.starts_on, period.opening_date, period.closing_date) AS current_recurrence_on
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
            AND transaction_recurrences.starts_on <= period.closing_date
       ORDER BY transaction_recurrences.starts_on DESC
          LIMIT 1
       ) AS current_transaction_recurrences ON true
 WHERE transactions.user_id = :user_id
   AND CASE transactions.recurrence_type
         WHEN 'one_time' THEN current_transaction_recurrences.starts_on >= period.opening_date
         ELSE (
                (
                  transactions.ends_on IS NULL OR
                  first_transaction_recurrences.current_recurrence_on <= transactions.ends_on OR
                  (
                    first_transaction_recurrences.current_recurrence_on = period.opening_date AND
                    first_transaction_recurrences.current_recurrence_on = transactions.ends_on + 1 AND
                    EXTRACT(DAY FROM first_transaction_recurrences.first_recurrence_on) <> EXTRACT(DAY FROM first_transaction_recurrences.current_recurrence_on)
                  )
                ) AND
                first_transaction_recurrences.current_recurrence_on >= first_transaction_recurrences.first_recurrence_on AND
                first_transaction_recurrences.current_recurrence_on BETWEEN period.opening_date AND period.closing_date
              )
       END
   AND (transactions.canceled_on IS NULL OR first_transaction_recurrences.current_recurrence_on <= transactions.canceled_on)
