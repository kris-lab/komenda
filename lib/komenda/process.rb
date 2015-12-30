module Komenda
  class Process
    attr_reader :output

    include Events::Emitter

    # @param [ProcessBuilder] process_builder
    def initialize(process_builder)
      @process_builder = process_builder
      @output = { stdout: '', stderr: '', combined: '' }
      @exit_status = @thread = @pid = nil

      on(:stdout) { |data| @output[:stdout] += data }
      on(:stderr) { |data| @output[:stderr] += data }
      on(:output) { |data| @output[:combined] += data }
      process_builder.events.each do |event|
        on(event[:type], &event[:listener])
      end
    end

    # @return [Thread]
    def start
      fail 'Already started' if started?
      @thread = Thread.new { run_process(@process_builder) }
    end

    # @return [Komenda::Result]
    def wait_for
      fail 'Process not started' unless started?
      @thread.join
      result
    end

    # @return [Komenda::Result]
    def run
      start unless started?
      wait_for
    end

    # @return [Integer]
    def pid
      fail 'No PID available' if @pid.nil?
      @pid
    end

    # @param [Integer, String]
    def kill(signal = 'TERM')
      ::Process.kill(signal, pid)
    end

    # @return [TrueClass, FalseClass]
    def running?
      started? && !@pid.nil? && !finished?
    end

    # @return [Komenda::Result]
    def result
      fail 'Process not started' unless started?
      fail 'Process not finished' unless finished?
      Komenda::Result.new(@output, @exit_status)
    end

    private

    # @return [TrueClass, FalseClass]
    def started?
      !@thread.nil?
    end

    # @return [TrueClass, FalseClass]
    def finished?
      !@exit_status.nil?
    end

    # @param [ProcessBuilder] process_builder
    def run_process(process_builder)
      if process_builder.cwd.nil?
        run_popen3(process_builder)
      else
        Dir.chdir(process_builder.cwd) { run_popen3(process_builder) }
      end
    rescue Exception => exception
      emit(:error, exception)
      raise exception
    end

    # @param [ProcessBuilder] process_builder
    def run_popen3(process_builder)
      Open3.popen3(process_builder.env, *process_builder.command) do |stdin, stdout, stderr, wait_thr|
        @pid = wait_thr.pid
        stdin.close
        read_streams([stdout, stderr]) do |data, stream|
          emit(:output, data)
          emit(:stdout, data) if stdout == stream
          emit(:stderr, data) if stderr == stream
        end
        @exit_status = wait_thr.value
        emit(:exit, result)
      end
    end

    # @param [Array<IO>] streams
    def read_streams(streams)
      select_streams(streams) do |stream|
        if stream.eof?
          stream.close
        else
          data = stream.readpartial(4096)
          yield(data, stream)
        end
      end
    end

    # @param [Array<IO>] streams
    def select_streams(streams)
      loop do
        streams_available, = IO.select(streams)
        streams_available.each do |stream|
          yield(stream)
        end
        streams.reject!(&:closed?)
        break if streams.empty?
      end
    end
  end
end
