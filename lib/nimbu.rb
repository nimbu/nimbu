require "nimbu/version"
require "nimbu/client"

module Nimbu
  def self.debug=(value)
    @@debug = value
  end

  def self.debug
    @@debug
  end

  def self.development=(value)
    @@development = value
  end

  def self.development
    @@development
  end
end
