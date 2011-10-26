require 'optparse'

module Capistrano
  module Calendar
    class Runner
      def self.run(*args)
        new(*args).run!
      end

      def initialize(argv)
        @argv = argv
      end

      attr_reader :client

      def run!
        parser = OptionParser.new do |o|
          o.banner = "Usage: capistrano-calendar [options] COMMAND [CONFIGURATION_DATA]"
          o.separator ""
          o.separator "Commands:"
          o.separator ""
          o.separator "  create_event - create calendar event"
          o.separator ""
          o.separator "CONFIGURATION_DATA is base64 encoded yaml data" 
          o.separator ""
          o.separator "Common options:"
          o.on_tail("-h", "--help", "Show this message") { puts o; exit }
          o.on_tail('-v', '--version', "Show version")   { puts Capistrano::Calendar::VERSION; exit }
        end
        
        parser.parse!(@argv)

        @command       = @argv.shift
        @configuration = @argv.shift

        case @command
        when 'create_event'
          @configuration or abort(parser.help)
          @configuration = Capistrano::Calendar::Configuration.decode(@configuration)
          @configuration.is_a?(Hash) or abort("Bad configuration given")

          @client = Capistrano::Calendar::Client.new(@configuration)
      
          daemonize { create_event }
        else
          abort parser.help
        end

      end

      protected

      def create_event
        client.authenticate
        client.create_event
      end

      def daemonize
        Process.fork do
          # Detach the child process from the parent's session.
          Process.setsid

          # Re-fork. This is recommended for System V-based
          # system as it guarantees that the daemon is not a
          # session leader, which prevents it from aquiring
          # a controlling terminal under the System V rules.
          exit if fork

          # Rename the process
          $0 = "capistrano-calendar"

          # Flush all buffers
          $stdout.sync = $stderr.sync = true

          # Set all standard files to `/dev/null/` in order
          # to be sure that any output from the daemon will
          # not appear in any terminals.
          $stdin.reopen("/dev/null")
          $stdout.reopen("/tmp/capistrano-calendar.stdout")
          $stderr.reopen("/tmp/capistrano-calendar.stderr")

          yield
        end
      end

    end
  end
end
