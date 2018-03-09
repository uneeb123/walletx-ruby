require_relative 'controller'

module Bitcoin
  class PingController < Bitcoin::Controller
    def do_work
      ping
    end

    def ping
      puts "Pinging..."
    end
  end
end
