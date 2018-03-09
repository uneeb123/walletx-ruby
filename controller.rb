require 'eventmachine'

require_relative 'peer_searcher'
require_relative 'connector'

module Bitcoin
  
  MAINNET_PORT = 8333
  
  class Controller

    attr_reader :host

    def initialize
      @peer_searcher = Bitcoin::PeerSearcher.new
      @host = @peer_searcher.first_attempt
      puts "Attempting to connect to #{@host.to_s}"
      EventMachine::connect(@host.to_s, Bitcoin::MAINNET_PORT, Bitcoin::Connector, self)
    end

    def reconnect
      @host = @peer_searcher.next_attempt
      puts "Attempting to connect to #{@random_address}"
      EventMachine::connect(@host.to_s, Bitcoin::MAINNET_PORT, Bitcoin::Connector, self)
    end
  end
end
