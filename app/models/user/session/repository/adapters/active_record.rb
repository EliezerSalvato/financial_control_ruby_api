module User::Session::Repository::Adapters::ActiveRecord
  include Core::User::Session::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(user:, user_agent:, ip_address:, refresh_token:, remember_me:, token_adapter: User::Adapters.token, **)
    session = User::Session::Record.create(
      user_id: user.id,
      user_agent:,
      ip_address:,
      refresh_token_digest: token_adapter.digest(refresh_token),
      refresh_token_expires_at: Core::User::Token.refresh_token_expires_in(remember_me:).from_now
    )

    return Success(:session_created, session: User::Session::Mapper.to_entity(session)) if session.persisted?

    Failure(
      :session_creation_failed,
      session: User::Session::Mapper.to_entity(session),
      errors: User::Session::Mapper.to_errors(session)
    )
  end

  def revoke_all_by(user_id:, **)
    User::Session::Record.active.where(user_id:).update_all(refresh_token_expires_at: 1.second.ago)

    Success(:sessions_revoked)
  rescue ActiveRecord::ActiveRecordError
    Failure(:sessions_revocation_failed)
  end

  def find_by_refresh_token(refresh_token:, token_adapter: User::Adapters.token, **)
    session = User::Session::Record.active.find_by(refresh_token_digest: token_adapter.digest(refresh_token))

    if session.present?
      return Success(
        :session_found,
        session: User::Session::Mapper.to_entity(session),
        user: User::Mapper.to_entity(session.user)
      )
    end

    Failure(:invalid_refresh_token)
  end

  def update_refresh_token(session:, refresh_token:, remember_me:, token_adapter: User::Adapters.token, **)
    record = User::Session::Mapper.to_record(session)
    updated = record.update(
      refresh_token_digest: token_adapter.digest(refresh_token),
      refresh_token_expires_at: Core::User::Token.refresh_token_expires_in(remember_me:).from_now
    )

    return Success(:refresh_token_updated, session: User::Session::Mapper.to_entity(record)) if updated

    Failure(
      :refresh_token_update_failed,
      session: User::Session::Mapper.to_entity(record),
      errors: User::Session::Mapper.to_errors(record)
    )
  end
end
