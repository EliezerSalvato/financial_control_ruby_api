class CreateFunctionMakeDateClamped < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION make_date_clamped(
        _year INT,
        _month INT,
        _day INT
      )
      RETURNS DATE
      IMMUTABLE
      STRICT
      AS $BODY$
        SELECT make_date(
          _year,
          _month,
          LEAST(
            _day,
            EXTRACT(
              DAY FROM (
                make_date(_year, _month, 1)
                + INTERVAL '1 month - 1 day'
              )
            )::INT
          )
        );
      $BODY$
      LANGUAGE sql;
    SQL
  end

  def down
    execute <<-SQL
      DROP FUNCTION IF EXISTS make_date_clamped(INT, INT, INT);
    SQL
  end
end
