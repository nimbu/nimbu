# -*- encoding : utf-8 -*-
require "nimbu/version"
require "nimbu-api"

module Nimbu
  def self.debug=(value)
    @debug = value
  end

  def self.debug
    @debug || false
  end
end
