module Transaction::Settlement::Mapper
  extend self

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
