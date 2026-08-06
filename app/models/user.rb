module User
  extend Solid::Context

  self.actions = {
    register: Core::User::Registration,
    authenticate: Core::User::Authentication,
    delete_account: Core::User::Account::Deletion,
    confirm_email: Core::User::Email::Confirmation,
    change_email: Core::User::Email::Change,
    change_password: Core::User::Password::Change,
    send_reset_password_instructions: Core::User::Password::Reset::SendInstructions,
    reset_password: Core::User::Password::Reset,
    update_profile: Core::User::Profile::Update,
    refresh_session: Core::User::Session::Refresh,
    revoke_sessions: Core::User::Session::Revoke
  }
end
