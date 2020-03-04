require 'yell'

module Nomade
  def self.logger
    $logger ||= begin
      stdout = if ARGV.include?("-d") || ARGV.include?("--debug")
        [:debug, :info, :warn]
      else
        [:info, :warn]
      end

      Yell.new do |l|
        unless ARGV.include?("-q")
          l.adapter STDOUT, level: stdout
          l.adapter STDERR, level: [:error, :fatal]
        end
      end
    end
  end
end
