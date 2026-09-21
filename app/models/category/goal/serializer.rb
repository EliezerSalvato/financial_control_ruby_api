class Category::Goal::Serializer
  include JSONAPI::Serializer

  set_type :category_goal
  attributes :id, :month, :year, :value
end
