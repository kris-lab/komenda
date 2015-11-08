module Komenda
  class ProcessBuilder

    attr_reader :command
    attr_reader :env
    attr_reader :events

    # @param [String] command
    # @param [Hash] options
    def initialize(command, options = {})
      defaults = {
        :env => ENV.to_hash,
        :events => {}
      }
      options = defaults.merge(options)

      @command = String(command)
      @env = Hash[options[:env].to_hash.map { |k, v| [String(k), String(v)] }]
      @events = Hash[options[:events].to_hash.map { |k, v| [k.to_sym, v.to_proc] }]
    end

    # @return [Komenda::Process]
    def create
      Komenda::Process.new(self)
    end

  end
end
