Core::Notification::Entity = Data.define(
  :id,
  :user_id,
  :kind,
  :title,
  :body,
  :read,
  :read_at,
  :notifiable_type,
  :notifiable_id,
  :data,
  :created_at
) do
  def read? = read

  def unread? = !read
end
