WITH period AS (
  SELECT make_date(:year, :month, 1) AS starts_on,
         :year AS year,
         :month AS month
)
SELECT categories.id,
       'category'::text AS kind,
       categories.name,
       categories.color,
       current_goals.value
  FROM period
  JOIN categories
    ON categories.user_id = :user_id
   AND (categories.goal_ends_on IS NULL OR categories.goal_ends_on >= period.starts_on)
  JOIN LATERAL (
         SELECT category_goals.value
           FROM category_goals
          WHERE category_goals.category_id = categories.id
            AND (category_goals.year < period.year
                 OR (category_goals.year = period.year AND category_goals.month <= period.month))
       ORDER BY category_goals.year DESC, category_goals.month DESC
          LIMIT 1
       ) AS current_goals ON true
UNION ALL
SELECT tags.id,
       'tag'::text AS kind,
       tags.name,
       tags.color,
       current_goals.value
  FROM period
  JOIN tags
    ON tags.user_id = :user_id
   AND (tags.goal_ends_on IS NULL OR tags.goal_ends_on >= period.starts_on)
  JOIN LATERAL (
         SELECT tag_goals.value
           FROM tag_goals
          WHERE tag_goals.tag_id = tags.id
            AND (tag_goals.year < period.year
                 OR (tag_goals.year = period.year AND tag_goals.month <= period.month))
       ORDER BY tag_goals.year DESC, tag_goals.month DESC
          LIMIT 1
       ) AS current_goals ON true
 ORDER BY kind, name, id
