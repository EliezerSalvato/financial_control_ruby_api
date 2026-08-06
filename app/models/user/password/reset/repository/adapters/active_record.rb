module User::Password::Reset::Repository::Adapters::ActiveRecord
  include Core::User::Password::Reset::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(user:, token_adapter: User::Adapters.token, **)
    token = token_adapter.generate_for(user:, purpose: :reset_password)

    password_reset = User::Password::Reset::Record.create(
      user_id: user.id,
      token_digest: token_adapter.digest(token),
      expires_at: Core::User::Password::RESET_TOKEN_EXPIRES_IN.from_now
    )

    if password_reset.persisted?
      return Success(
        :password_reset_created,
        password_reset: User::Password::Reset::Mapper.to_entity(password_reset),
        token:
      )
    end

    Failure(
      :password_reset_creation_failed,
      password_reset: User::Password::Reset::Mapper.to_entity(password_reset),
      errors: User::Password::Reset::Mapper.to_errors(password_reset)
    )
  end

  def invalidate_all_by(user_id:, **)
    User::Password::Reset::Record.pending.where(user_id:).update_all(expires_at: 1.second.ago)

    Success(:password_resets_invalidated)
  rescue ActiveRecord::ActiveRecordError
    Failure(:password_resets_invalidation_failed)
  end

  def find_by_token(token:, token_adapter: User::Adapters.token, **)
    password_reset = User::Password::Reset::Record.pending.find_by(
      token_digest: token_adapter.digest(token)
    )

    if password_reset.present?
      return Success(
        :password_reset_found,
        password_reset: User::Password::Reset::Mapper.to_entity(password_reset)
      )
    end

    Failure(:password_reset_not_found)
  end

  def mark_as_reset(password_reset:)
    record = User::Password::Reset::Mapper.to_record(password_reset)
    marked_as_reset = record.update(reset_at: Time.current)

    if marked_as_reset
      return Success(
        :password_reset_marked_as_reset,
        password_reset: User::Password::Reset::Mapper.to_entity(record)
      )
    end

    Failure(:mark_password_reset_as_reset_failed)
  end
end
