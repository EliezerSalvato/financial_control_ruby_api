module User::Repository::Adapters::ActiveRecord
  include Core::User::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(**attributes)
    user = User::Record.create(attributes)

    return Success(:user_created, user: User::Mapper.to_entity(user)) if user.persisted?

    Failure(:user_creation_failed, user: User::Mapper.to_entity(user), errors: User::Mapper.to_errors(user))
  end

  def exists?(email:)
    User::Record.exists?(email:)
  end

  def verified?(user:)
    user.verified?
  end

  def active?(user:)
    user.active?
  end

  def find_by_email_and_password(email:, password:)
    user = User::Record.authenticate_by(email:, password:)

    return Success(:user_found, user: User::Mapper.to_entity(user)) if user.present?

    Failure(:invalid_email_or_password)
  end

  def find_by_confirmation_token(token:, token_adapter: User::Adapters.token, **)
    user = token_adapter.find_by(purpose: :email_confirmation, token:)

    return Success(:user_found, user:) if user.present?

    Failure(:invalid_token)
  end

  def find_by_email(email:)
    user = User::Record.find_by(email:)

    return Success(:user_found, user: User::Mapper.to_entity(user)) if user.present?

    Failure(:user_not_found)
  end

  def find_by_id(id:)
    user = User::Record.find_by(id:)

    return Success(:user_found, user: User::Mapper.to_entity(user)) if user.present?

    Failure(:user_not_found)
  end

  def find_by_reset_password_token(token:, token_adapter: User::Adapters.token, **)
    user = token_adapter.find_by(purpose: :reset_password, token:)

    return Success(:user_found, user:) if user.present?

    Failure(:invalid_token)
  end

  def mark_as_verified(user:)
    record = User::Mapper.to_record(user)
    verified = record.update(verified: true)

    return Success(:user_verified, user: User::Mapper.to_entity(record)) if verified

    Failure(:mark_user_as_verified_failed)
  end

  def change_email_and_mark_as_not_verified(user:, new_email:)
    record = User::Mapper.to_record(user)
    updated = record.update(email: new_email, verified: false)

    return Success(:user_email_changed, user: User::Mapper.to_entity(record)) if updated

    Failure(:change_email_and_mark_as_not_verified_failed)
  end

  def authenticate(user:, password:)
    record = User::Mapper.to_record(user)

    return Success(:authenticated, user: User::Mapper.to_entity(record)) if record.authenticate(password)

    Failure(:current_password_is_invalid)
  end

  def update_password(user:, password:, password_confirmation:)
    record = User::Mapper.to_record(user)
    updated = record.update(password:, password_confirmation:)

    return Success(:password_updated, user: User::Mapper.to_entity(record)) if updated

    Failure(:password_update_failed, user: User::Mapper.to_entity(record), errors: User::Mapper.to_errors(record))
  end

  def update_profile(user:, first_name: nil, last_name: nil, configs: nil)
    record = User::Mapper.to_record(user)
    attributes = { first_name:, last_name:, configs: }.compact
    updated = record.update(attributes)

    return Success(:profile_updated, user: User::Mapper.to_entity(record)) if updated

    Failure(:profile_update_failed, user: User::Mapper.to_entity(record), errors: User::Mapper.to_errors(record))
  end

  def destroy(user:)
    record = User::Mapper.to_record(user)

    return Success(:user_destroyed) if record.destroy

    Failure(:user_destruction_failed)
  end
end
