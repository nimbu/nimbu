require 'nimbu-api'

module Nimbu
  def self.debug=(value)
    @debug = value
  end

  def self.debug
    @debug || false
  end

  def self.cli_options
    @cli_options ||= {}
  end
end
