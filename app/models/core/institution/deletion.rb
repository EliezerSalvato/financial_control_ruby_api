class Core::Institution::Deletion < ApplicationSolidProcess
  deps do
    attribute :institution_repository, default: -> { Institution::Adapters.repository }
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }

    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_institution)
      .and_then(:reject_if_used_by_transactions)
      .and_then(:destroy_institution)
  end

  private

  def find_institution(user:, id:, **)
    case deps.institution_repository.find_by_id(user:, id:)
    in Solid::Success(institution:) then Continue(institution:)
    in Solid::Failure(type: :institution_not_found)
      Failure(:institution_not_found)
    end
  end

  def reject_if_used_by_transactions(user:, institution:, **)
    return Continue() unless deps.transaction_repository.exists_by_institution_id?(user:, institution_id: institution.id)

    input.errors.add(:base, :used_by_transactions)
    Failure(:institution_used_by_transactions, input:)
  end

  def destroy_institution(institution:, **)
    case deps.institution_repository.destroy(institution:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :institution_destruction_failed)

      Failure(:institution_destruction_failed, input:)
    end
  end
end
