class Tag::Serializer
  include JSONAPI::Serializer

  set_type :tag
  attributes :id, :name, :color, :active, :goal_ends_on

  attribute :current_goal do |tag|
    goal = tag.current_goal
    goal ? Tag::Goal::Serializer.new(goal).serializable_hash.fetch(:data) : nil
  end

  attribute :goals do |tag|
    Tag::Goal::Serializer.new(tag.goals).serializable_hash.fetch(:data)
  end
end
