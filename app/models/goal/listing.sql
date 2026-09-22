WITH statements AS (
  __STATEMENTS_SQL__
),
transfers AS (
  __TRANSFERS_SQL__
),
period_items AS (
  SELECT id, kind, description, recurrence_type, value,
         first_recurrence_on, current_recurrence_on, ends_on
    FROM statements
  UNION ALL
  SELECT id, kind, description, recurrence_type, value,
         first_recurrence_on, current_recurrence_on, ends_on
    FROM transfers
)
SELECT period_items.id,
       period_items.kind,
       period_items.description,
       period_items.recurrence_type,
       period_items.value,
       period_items.first_recurrence_on,
       period_items.current_recurrence_on,
       period_items.ends_on,
       transactions.category_id,
       COALESCE(tagged.tag_ids, '{}'::uuid[]) AS tag_ids
  FROM period_items
  JOIN transactions
    ON transactions.id = period_items.id
  LEFT JOIN LATERAL (
         SELECT array_agg(transaction_tags.tag_id ORDER BY transaction_tags.tag_id) AS tag_ids
           FROM transaction_tags
          WHERE transaction_tags.transaction_id = period_items.id
       ) AS tagged ON true
 ORDER BY period_items.current_recurrence_on, period_items.description
