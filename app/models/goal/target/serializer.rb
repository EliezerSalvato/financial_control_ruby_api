class Goal::Target::Serializer
  include JSONAPI::Serializer

  set_type :goal_target
  attributes :id, :kind, :name, :color, :value
end
