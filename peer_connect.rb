require 'eventmachine'
require 'socket'
require 'digest/sha2'

require_relative 'network/transreceiver'

module Bitcoin

  PROTOCOL_VERSION = 70001
  NODE_NETWORK = 1

  class ConnectionHandler < EventMachine::Connection
    def initialize host, port, connections
      @transreceiver = Bitcoin::Transreceiver.new(self)
      @sockaddr = [port, host]
      @connections = connections
    end

    def post_init
      puts "connected with #{@sockaddr[1]}:#{@sockaddr[0]}"
      EventMachine::schedule { handshake_begin }
    end

    def receive_data data
      @transreceiver.receive_packets(data)
    end

    def unbind
      puts "Disconnected"
      exit
    end

    # https://bitcoin.org/en/developer-reference#version
    def version_message
      fields = {                                                                           
        version: PROTOCOL_VERSION,
        services: NODE_NETWORK,
        nonce: rand(0xffffffffffffffff),
        from: "127.0.0.1:8333",
        to: @sockaddr.reverse.join(":"),
        last_block: 0,
        time: Time.now.tv_sec,
        user_agent: "/bitcoin-ruby-lite:0.1/",
        relay: true
      }
      @transreceiver.transmit_version_message fields
    end

    def handshake_begin
      version_message
    end
  end
end

SEEDS = ["seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "dnsseed.bitcoin.dashjr.org", "bitseed.xf2.org", "dnsseed.webbtc.com"]
MAINNET_PORT = 8333

# Establishes client connection with peers
EventMachine::run do
  connections = []
  begin
    all_seeds = SEEDS.dup
    random_seed = all_seeds.sample
    addresses = nil
    loop do
      addresses = Resolv::DNS.new.getaddresses(random_seed)
      if addresses != []
        break
      end
      all_seeds.delete(random_seed)
      if all_seeds.empty?
        raise "All seeds exhausted"
      end
      random_seed = all_seeds.sample
    end
    random_peer_addr = addresses.sample
    peer_host = random_peer_addr.to_s
  rescue Errno::ECONNREFUSED => e
    require 'pry'; binding.pry
    raise e
  end

  begin
    EventMachine::connect(peer_host, MAINNET_PORT, Bitcoin::ConnectionHandler, peer_host, MAINNET_PORT, connections)
  rescue EventMachine::ConnectionError => e
    require 'pry'; binding.pry
    raise e
  end
end
