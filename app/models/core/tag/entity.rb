Core::Tag::Entity = Data.define(:id, :user_id, :name, :color, :active, :goal_ends_on, :goals) do
  def initialize(id:, user_id:, name:, color:, active:, goal_ends_on: nil, goals: [])
    super
  end

  def active? = active

  def current_goal = goal_on(Date.current)

  def goal_on(date)
    return if goals.empty?
    return if goal_ends_on.present? && date.beginning_of_month > goal_ends_on.beginning_of_month

    as_of_month = date.beginning_of_month

    goals
      .select { |goal| goal.starts_on <= as_of_month }
      .max_by(&:starts_on) || goals.min_by(&:starts_on)
  end
end
