class CreateFunctionCreditCardBillingCycleDates < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION credit_card_billing_cycle_dates(
        _credit_card_id UUID,
        _month INT,
        _year INT
      )
      RETURNS TABLE (
        opening_date DATE,
        closing_date DATE,
        due_date DATE
      )
      AS $BODY$
      DECLARE
        _due_day INT;
        _closing_day INT;
        _closing_month DATE;
        _previous_closing_date DATE;
      BEGIN
        SELECT due_day,
               closing_day
          INTO _due_day,
               _closing_day
          FROM credit_cards
         WHERE id = _credit_card_id;

        _closing_month := make_date(_year, _month, 1);

        IF _closing_day > _due_day THEN
          _closing_month := _closing_month - INTERVAL '1 month';
        END IF;

        closing_date := make_date_clamped(
          EXTRACT(YEAR FROM _closing_month)::INT,
          EXTRACT(MONTH FROM _closing_month)::INT,
          _closing_day
        );

        due_date := make_date_clamped(
          _year,
          _month,
          _due_day
        );

        _previous_closing_date := make_date_clamped(
          EXTRACT(YEAR FROM closing_date - INTERVAL '1 month')::INT,
          EXTRACT(MONTH FROM closing_date - INTERVAL '1 month')::INT,
          _closing_day
        );

        opening_date := _previous_closing_date + 1;

        RETURN NEXT;
      END;
      $BODY$
      LANGUAGE plpgsql;
    SQL
  end

  def down
    execute <<-SQL
      DROP FUNCTION IF EXISTS credit_card_billing_cycle_dates(UUID, INT, INT);
    SQL
  end
end
