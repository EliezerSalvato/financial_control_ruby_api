class Goal::Serializer
  include JSONAPI::Serializer

  set_type :goal_transaction
  attributes :id,
             :kind,
             :description,
             :recurrence_type,
             :value,
             :first_recurrence_on,
             :current_recurrence_on,
             :ends_on,
             :category_id,
             :tag_ids
end
