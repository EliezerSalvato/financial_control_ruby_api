class Tag::Goal::Serializer
  include JSONAPI::Serializer

  set_type :tag_goal
  attributes :id, :month, :year, :value
end
