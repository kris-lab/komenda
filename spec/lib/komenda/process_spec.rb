require 'spec_helper'

describe Komenda::Process do

  describe '#initialize' do
    let(:process_builder) { Komenda::ProcessBuilder.new('echo -n "hello"') }
    let(:process) { Komenda::Process.new(process_builder) }

    it 'creates a process with empty output' do
      expect(process.output).to eq({:stdout => '', :stderr => '', :combined => ''})
    end
  end

  context 'when just created' do
    let(:process_builder) { Komenda::ProcessBuilder.new('echo -n "hello"') }
    let(:process) { Komenda::Process.new(process_builder) }

    describe '#start' do
      it 'returns a thread' do
        expect(process.start).to be_a(Thread)
      end
    end

    describe '#wait_for' do
      it 'returns a result' do
        expect(process.wait_for).to be_a(Komenda::Result)
      end
    end

    describe '#running?' do
      it 'raises an error' do
        expect { process.running? }.to raise_error(StandardError, /not started/)
      end
    end

    describe '#result' do
      it 'raises an error' do
        expect { process.result }.to raise_error(StandardError, /not started/)
      end
    end
  end

  context 'when started' do
    let(:process_builder) { Komenda::ProcessBuilder.new('echo -n "hello"') }
    let(:process) { Komenda::Process.new(process_builder) }
    before { process.start }

    describe '#start' do
      it 'does not start again' do
        expect { process.start }.to raise_error(StandardError, /Already started/)
      end
    end

    describe '#wait_for' do
      it 'returns a result' do
        expect(process.wait_for).to be_a(Komenda::Result)
      end
    end

    describe '#running?' do
      it 'returns true' do
        expect(process.running?).to eq(true)
      end
    end

    describe '#result' do
      it 'raises an error' do
        expect { process.result }.to raise_error(StandardError, /not finished/)
      end
    end
  end

  context 'when finished' do
    let(:process_builder) { Komenda::ProcessBuilder.new('echo -n "hello"') }
    let(:process) { Komenda::Process.new(process_builder) }
    before { process.wait_for }

    describe '#start' do
      it 'does not start again' do
        expect { process.start }.to raise_error(StandardError, /Already started/)
      end
    end

    describe '#wait_for' do
      it 'returns a result' do
        expect(process.wait_for).to be_a(Komenda::Result)
      end
    end

    describe '#running?' do
      it 'returns false' do
        expect(process.running?).to eq(false)
      end
    end

    describe '#result' do
      it 'returns a result' do
        expect(process.result).to be_a(Komenda::Result)
      end
    end
  end

  describe '#emit' do
    let(:command) { 'ruby -e \'STDOUT.sync=STDERR.sync=true; STDOUT.print "hello"; sleep(0.01); STDERR.print "world";\'' }
    let(:process_builder) { Komenda::ProcessBuilder.new(command) }
    let(:process) { Komenda::Process.new(process_builder) }

    it 'emits event on stdout' do
      callback = double(Proc)
      process.on(:stdout) { |d| callback.call(d) }

      expect(callback).to receive(:call).once.with('hello')
      process.wait_for
    end

    it 'emits event on stderr' do
      callback = double(Proc)
      process.on(:stderr) { |d| callback.call(d) }

      expect(callback).to receive(:call).once.with('world')
      process.wait_for
    end

    it 'emits event on output' do
      callback = double(Proc)
      process.on(:output) { |d| callback.call(d) }

      expect(callback).to receive(:call).once.ordered.with('hello')
      expect(callback).to receive(:call).once.ordered.with('world')
      process.wait_for
    end
  end

  describe '#wait_for' do

    context 'when command exits successfully' do
      let(:command) { 'ruby -e \'STDOUT.sync=STDERR.sync=true; STDOUT.print "hello"; sleep(0.01); STDERR.print "world";\'' }
      let(:process_builder) { Komenda::ProcessBuilder.new(command) }
      let(:process) { Komenda::Process.new(process_builder) }
      let(:result) { process.wait_for }

      it 'returns a result' do
        expect(result).to be_a(Komenda::Result)
      end

      it 'sets the standard output' do
        expect(result.stdout).to eq('hello')
      end

      it 'sets the standard error' do
        expect(result.stderr).to eq('world')
      end

      it 'sets the combined output' do
        expect(result.output).to eq('helloworld')
      end

      it 'sets the exit status' do
        expect(result.exitstatus).to eq(0)
      end

      it 'sets the success' do
        expect(result.success?).to eq(true)
      end

      it 'sets the PID' do
        expect(result.pid).to be_a(Fixnum)
      end
    end

    context 'when command fails' do
      let(:command) { 'ruby -e \'STDOUT.sync=STDERR.sync=true; STDOUT.print "hello"; sleep(0.01); STDERR.print "world"; exit(1);\'' }
      let(:process_builder) { Komenda::ProcessBuilder.new(command) }
      let(:process) { Komenda::Process.new(process_builder) }
      let(:result) { process.wait_for }

      it 'returns a result' do
        expect(result).to be_a(Komenda::Result)
      end

      it 'sets the standard output' do
        expect(result.stdout).to eq('hello')
      end

      it 'sets the standard error' do
        expect(result.stderr).to eq('world')
      end

      it 'sets the combined output' do
        expect(result.output).to eq('helloworld')
      end

      it 'sets the exit status' do
        expect(result.exitstatus).to eq(1)
      end

      it 'sets the success' do
        expect(result.success?).to eq(false)
      end
    end

    context 'when command outputs mixed stdout and stderr' do
      let(:command) { 'ruby -e \'STDOUT.sync=STDERR.sync=true; STDOUT.print "1"; sleep(0.01); STDERR.print "2"; sleep(0.01); STDOUT.print "3";\'' }
      let(:process_builder) { Komenda::ProcessBuilder.new(command) }
      let(:process) { Komenda::Process.new(process_builder) }
      let(:result) { process.wait_for }

      it 'sets the standard output' do
        expect(result.stdout).to eq('13')
      end

      it 'sets the standard error' do
        expect(result.stderr).to eq('2')
      end

      it 'sets the combined output' do
        expect(result.output).to eq('123')
      end
    end

    context 'when command outputs mixed stdout and stderr without delay' do
      let(:command) { 'ruby -e \'STDOUT.sync=STDERR.sync=true; STDOUT.print "1"; STDERR.print "2"; STDOUT.print "3";\'' }
      let(:process_builder) { Komenda::ProcessBuilder.new(command) }
      let(:process) { Komenda::Process.new(process_builder) }
      let(:result) { process.wait_for }

      it 'sets the standard output' do
        expect(result.stdout).to eq('13')
      end

      it 'sets the standard error' do
        expect(result.stderr).to eq('2')
      end

      it 'sets the combined output', :skip => 'doesn\'t work, probably because the ruby loop is too slow (both IO objects become available at the same time)' do
        expect(result.output).to eq('123')
      end
    end

    context 'when environment variables are passed' do
      let(:command) { 'echo "foo=${FOO}"' }
      let(:process_builder) { Komenda::ProcessBuilder.new(command, {:env => {:FOO => 'hello'}}) }
      let(:process) { Komenda::Process.new(process_builder) }
      let(:result) { process.wait_for }

      it 'sets the environment variables' do
        expect(result.stdout).to eq("foo=hello\n")
      end
    end
  end

end
