# Checks that the categories and tags an effect points to belong to the user.
module Core::Transaction::Import::Rule::Effect::References
  def self.validate(errors, user:, effects:, category_repository:, tag_repository:)
    effects&.each do |effect|
      invalid_fields(effect, user:, category_repository:, tag_repository:).each do |field|
        errors.add(:effects, :invalid_effect, position: effect[:position] + 1, field:)
      end
    end
  end

  def self.invalid_fields(effect, user:, category_repository:, tag_repository:)
    [
      (:category_id if effect[:category_id] && !category_repository.find_by_id(user:, id: effect[:category_id]).success?),
      (:tag_ids if effect[:tag_ids].any? && !tag_repository.find_by_ids(user:, ids: effect[:tag_ids]).success?)
    ].compact
  end
  private_class_method :invalid_fields
end
