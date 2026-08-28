namespace :monthly_statuses do
  desc "Creates the initial monthly_statuses rows for each user, from the oldest transaction month through the current month"
  task backfill: :environment do
    now = Time.current
    total = 0

    User::Record.find_each do |user|
      starts_on = Transaction::Recurrence::Record
        .joins(:financial_transaction)
        .where(transactions: { user_id: user.id })
        .minimum(:starts_on)

      next if starts_on.nil?

      cursor = starts_on.beginning_of_month
      last = Date.new(now.year, now.month, 1)
      rows = []

      while cursor <= last
        rows << {
          user_id: user.id,
          month: cursor.month,
          year: cursor.year,
          status: "open",
          created_at: now,
          updated_at: now
        }
        cursor = cursor.next_month
      end

      next if rows.empty?

      inserted = MonthlyStatus::Record.insert_all(rows, unique_by: %i[user_id month year])
      created = inserted.count
      total += created
      puts "user=#{user.id} created=#{created}"
    end

    puts "total=#{total}"
  end
end
