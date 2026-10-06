module Core::Color
  FORMAT = /\A#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\z/

  def self.random = format("#%06X", Random.rand(0x1000000))
end
