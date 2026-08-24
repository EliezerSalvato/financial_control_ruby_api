class CreateFunctionMonthlyOccurrenceOn < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION monthly_occurrence_on(
        _first_starts_on DATE,
        _opening_date DATE,
        _closing_date DATE
      )
      RETURNS DATE
      IMMUTABLE
      AS $BODY$
        SELECT GREATEST(
                 _first_starts_on,
                 CASE
                   WHEN projected < _opening_date THEN
                     make_date_clamped(
                       EXTRACT(YEAR FROM (_opening_date + INTERVAL '1 month'))::INT,
                       EXTRACT(MONTH FROM (_opening_date + INTERVAL '1 month'))::INT,
                       EXTRACT(DAY FROM _first_starts_on)::INT
                     )
                   WHEN projected > _closing_date THEN
                     _opening_date
                   ELSE projected
                 END
               )
          FROM (
                 SELECT make_date_clamped(
                          EXTRACT(YEAR FROM _opening_date)::INT,
                          EXTRACT(MONTH FROM _opening_date)::INT,
                          EXTRACT(DAY FROM _first_starts_on)::INT
                        ) AS projected
               ) AS projection
      $BODY$
      LANGUAGE sql;
    SQL
  end

  def down
    execute <<-SQL
      DROP FUNCTION IF EXISTS monthly_occurrence_on(DATE, DATE, DATE);
    SQL
  end
end
