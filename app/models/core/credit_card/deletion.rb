class Core::CreditCard::Deletion < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_credit_card)
      .and_then(:destroy_credit_card)
  end

  private

  def find_credit_card(user:, id:, **)
    case deps.credit_card_repository.find_by_id(user:, id:)
    in Solid::Success(credit_card:) then Continue(credit_card:)
    in Solid::Failure(type: :credit_card_not_found)
      Failure(:credit_card_not_found)
    end
  end

  def destroy_credit_card(credit_card:, **)
    case deps.credit_card_repository.destroy(credit_card:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :credit_card_destruction_failed)

      Failure(:credit_card_destruction_failed, input:)
    end
  end
end
