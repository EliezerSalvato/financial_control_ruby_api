class ApplicationSolidProcess < Solid::Process
  private

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
