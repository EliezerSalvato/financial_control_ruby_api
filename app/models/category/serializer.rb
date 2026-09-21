class Category::Serializer
  include JSONAPI::Serializer

  set_type :category
  attributes :id, :name, :color, :active, :goal_ends_on

  attribute :current_goal do |category|
    goal = category.current_goal
    goal ? Category::Goal::Serializer.new(goal).serializable_hash.fetch(:data) : nil
  end

  attribute :goals do |category|
    Category::Goal::Serializer.new(category.goals).serializable_hash.fetch(:data)
  end
end
