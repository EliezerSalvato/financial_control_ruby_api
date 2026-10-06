class Core::Transaction::Import::Rule::Deletion < ApplicationSolidProcess
  deps do
    attribute :import_rule_repository, default: -> { Transaction::Adapters.import_rule_repository }

    validates :import_rule_repository, kind_of: Core::Transaction::Import::Rule::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_import_rule)
      .and_then(:destroy_import_rule)
  end

  private

  def find_import_rule(user:, id:, **)
    case deps.import_rule_repository.find_by_id(user:, id:)
    in Solid::Success(import_rule:) then Continue(import_rule:)
    in Solid::Failure(type: :import_rule_not_found) then Failure(:import_rule_not_found)
    end
  end

  def destroy_import_rule(import_rule:, **)
    case deps.import_rule_repository.destroy(import_rule:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :import_rule_destruction_failed)

      Failure(:import_rule_destruction_failed, input:)
    end
  end
end
