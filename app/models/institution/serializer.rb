class Institution::Serializer
  include JSONAPI::Serializer

  set_type :institution
  attributes :id, :name, :logo_key, :active
end
