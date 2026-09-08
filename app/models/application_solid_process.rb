class ApplicationSolidProcess < Solid::Process
  private

  def with_nested_process(result, persist_failure: nil)
    case result
    in Solid::Success then Continue()
    in Solid::Failure(type: :invalid_input, value: { input: })
      merge_nested_input_errors(input)
      Failure(:invalid_input, input: self.input)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      self.input.errors.add(:base, persist_failure) if persist_failure
      Failure(persist_failure || :invalid_input, input: self.input)
    in Solid::Failure(input:)
      merge_nested_input_errors(input)
      Failure(:invalid_input, input: self.input)
    end
  end

  def merge_nested_input_errors(nested_input)
    nested_input.errors.details.each do |attribute, errors|
      errors.each { |detail| input.errors.add(attribute, detail[:error]) }
    end
  end

  def add_errors_to_input(source)
    to_core_errors(source).each do |attribute, message|
      input.errors.add(attribute, message)
    end
  end

  def to_core_errors(source)
    case source
    when Core::Errors then source
    when ->(value) { value.respond_to?(:errors) } then Core::Errors.new(source.errors.messages)
    when ->(value) { value.respond_to?(:messages) } then Core::Errors.new(source.messages)
    else raise ArgumentError, "unsupported errors source: #{source.class}"
    end
  end
end
