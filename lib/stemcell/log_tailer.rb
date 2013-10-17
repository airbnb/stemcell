require 'socket'
require 'net/ssh'

module Stemcell
  class LogTailer
    attr_reader :hostname
    attr_reader :username
    attr_reader :ssh_port

    attr_reader :finished
    attr_reader :interrupted

    # Don't wait more than two minutes
    MAX_WAIT_FOR_SSH = 120

    TAILING_COMMAND =
      "while [ ! -s /var/log/init ]; " \
      "do " \
        "printf '.' 1>&2; " \
        "sleep 1; " \
      "done; " \
      "echo ' /var/log/init exists!' 1>&2; " \
      "exec tail -qf /var/log/init*"

    def initialize(hostname, username, ssh_port=22)
      @hostname = hostname
      @username = username
      @ssh_port = ssh_port

      @finished = false
      @interrupted = false
    end

    def run!
      while_catching_interrupt do
        return unless wait_for_ssh
        tail_until_interrupt
      end
    end

    private

    def wait_for_ssh
      return if interrupted

      print "Waiting for sshd..."

      start_time = Time.now
      banner = nil

      loop do
        print "."
        begin
          banner = get_ssh_banner
          break
        rescue SocketError,
               IOError,
               Errno::ECONNREFUSED,
               Errno::ECONNRESET,
               Errno::EHOSTUNREACH,
               Errno::ENETUNREACH
          sleep 5
        rescue Errno::ETIMEDOUT,
               Errno::EPERM
        end

        # Don't wait forever
        if Time.now - start_time > MAX_WAIT_FOR_SSH
          puts " TIMEOUT!".red
          return false
        end

        if done?
          puts " ABORT!".red
          return false
        end
      end

      puts " UP!".green
      puts "Server responded with: #{banner.green}"
      true
    end

    def tail_until_interrupt
      return if interrupted

      session = Net::SSH.start(hostname, username)

      channel = session.open_channel do |ch|
        ch.request_pty do |ch, success|
          raise "Couldn't start a pseudo-tty!" unless success

          ch.on_data do |ch, data|
            STDOUT.print(data)
            @finished = true if contains_last_line?(data)
          end
          ch.on_extended_data do |c, type, data|
            STDERR.print(data)
          end

          ch.exec(TAILING_COMMAND)
        end
      end

      session.loop(1) do
        if done?
          # Send an interrupt to kill the remote process
          channel.send_data(Net::SSH::Connection::Term::VINTR)
          channel.send_data "exit\n"
          channel.eof!
          channel.close
          false
        else
          session.busy?
        end
      end

      session.close
    end

    def done?
      finished || interrupted
    end

    def get_ssh_banner
      socket = TCPSocket.new(hostname, ssh_port)
      IO.select([socket], nil, nil, 5) ? socket.gets : nil
    ensure
      socket.close if socket
    end

    def contains_last_line?(data)
      data =~ /#{Launcher::LAST_BOOTSTRAP_LINE}/
    end

    def while_catching_interrupt
      trap(:SIGINT) { @interrupted = true }
      yield
    ensure
      trap(:SIGINT, nil) 
    end
  end
end
