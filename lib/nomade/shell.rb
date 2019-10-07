require "open3"

module Nomade
  class Shell
    def self.exec(command, input = nil, allowed_exit_codes = [0])
      Nomade.logger.debug("+: #{command}")

      process, status, stdout, stderr = Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        if input
          stdin.puts(input)
        end
        stdin.close

        threads = {}.tap do |it|
          it[:stdout] = Thread.new do
            output = []
            stdout.each do |l|
              output << l
              Nomade.logger.debug(l)
            end
            Thread.current[:output] = output.join
          end

          it[:stderr] = Thread.new do
            output = []
            stderr.each do |l|
              output << l
              Nomade.logger.debug(l)
            end
            Thread.current[:output] = output.join
          end
        end
        threads.values.map(&:join)

        [wait_thread.value, wait_thread.value.exitstatus, threads[:stdout][:output], threads[:stderr][:output]]
      end

      unless allowed_exit_codes.include?(status)
        raise "`#{command}` failed with status=#{status}"
      end

      return [status, stdout, stderr]
    end
  end
end
