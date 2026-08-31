class User::Serializer
  include JSONAPI::Serializer

  attributes :id, :first_name, :last_name, :email, :configs
end
