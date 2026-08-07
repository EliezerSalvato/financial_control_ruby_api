class Category::Serializer
  include JSONAPI::Serializer

  set_type :category
  attributes :id, :name, :color, :active
end
