module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      user = find_verified_user
      reject_unauthorized_connection unless user&.active?

      self.current_user = user
    end

    private

    def find_verified_user
      token = request.params[:token].presence || bearer_token
      return if token.blank?

      User::Mapper.to_entity(User::Record.find_signed(token, purpose: :session_token))
    end

    def bearer_token
      request.headers["Authorization"]&.remove("Bearer ")
    end
  end
end
