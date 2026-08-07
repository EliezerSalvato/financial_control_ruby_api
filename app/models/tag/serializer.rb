class Tag::Serializer
  include JSONAPI::Serializer

  set_type :tag
  attributes :id, :name, :color, :active
end
