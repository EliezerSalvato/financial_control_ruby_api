module User::Email::Confirmation::Repository::Adapters::ActiveRecord
  include Core::User::Email::Confirmation::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(user:, old_email: nil, token_adapter: User::Adapters.token, **)
    token = token_adapter.generate_for(user:, purpose: :email_confirmation)

    email_confirmation = User::Email::Confirmation::Record.create(
      user_id: user.id,
      old_email:,
      new_email: user.email,
      token_digest: token_adapter.digest(token),
      expires_at: Core::User::Email::CONFIRMATION_TOKEN_EXPIRES_IN.from_now
    )

    if email_confirmation.persisted?
      return Success(
        :email_confirmation_created,
        email_confirmation: User::Email::Confirmation::Mapper.to_entity(email_confirmation),
        token:
      )
    end

    Failure(
      :email_confirmation_creation_failed,
      email_confirmation: User::Email::Confirmation::Mapper.to_entity(email_confirmation),
      errors: User::Email::Confirmation::Mapper.to_errors(email_confirmation)
    )
  end

  def invalidate_all_by(user_id:, **)
    User::Email::Confirmation::Record.pending.where(user_id:).update_all(expires_at: 1.second.ago)

    Success(:email_confirmations_invalidated)
  rescue ActiveRecord::ActiveRecordError
    Failure(:email_confirmations_invalidation_failed)
  end

  def find_by_token(token:, token_adapter: User::Adapters.token, **)
    email_confirmation = User::Email::Confirmation::Record.pending.find_by(
      token_digest: token_adapter.digest(token)
    )

    if email_confirmation.present?
      return Success(
        :email_confirmation_found,
        email_confirmation: User::Email::Confirmation::Mapper.to_entity(email_confirmation)
      )
    end

    Failure(:email_confirmation_not_found)
  end

  def mark_as_confirmed(email_confirmation:)
    record = User::Email::Confirmation::Mapper.to_record(email_confirmation)
    marked_as_confirmed = record.update(confirmed_at: Time.current)

    if marked_as_confirmed
      return Success(
        :email_confirmation_marked_as_confirmed,
        email_confirmation: User::Email::Confirmation::Mapper.to_entity(record)
      )
    end

    Failure(:mark_email_confirmation_as_confirmed_failed)
  end
end
