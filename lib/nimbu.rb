require "nimbu/version"
require "nimbu/client"

module Nimbu
  def self.debug=(value)
    @@debug = value
  end

  def self.debug
    @@debug
  end
end
