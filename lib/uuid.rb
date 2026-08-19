module UUID
  extend self

  REGEXP = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def generate
    SecureRandom.uuid_v7
  end

  def valid?(uuid)
    uuid => String

    uuid.match?(REGEXP)
  end

  def same?(left, right)
    left.is_a?(String) && right.is_a?(String) && valid?(left) && valid?(right) && left == right
  end
end
