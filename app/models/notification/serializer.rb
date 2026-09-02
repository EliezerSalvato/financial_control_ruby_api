class Notification::Serializer
  include JSONAPI::Serializer

  set_type :notification
  attributes :id, :kind, :title, :body, :read, :read_at,
             :notifiable_type, :notifiable_id, :data, :created_at
end
