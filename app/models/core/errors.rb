class Core::Errors
  attr_reader :messages

  def initialize(messages = {})
    @messages = messages.each_with_object({}) do |(attribute, attribute_messages), hash|
      hash[attribute.to_sym] = Array(attribute_messages).map(&:to_s)
    end
  end

  def any?
    messages.values.any?(&:any?)
  end

  def empty?
    !any?
  end

  def each
    return enum_for(:each) unless block_given?

    messages.each do |attribute, attribute_messages|
      attribute_messages.each { |message| yield attribute, message }
    end
  end
end
