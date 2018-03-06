require 'eventmachine'
require 'socket'
require 'digest/sha2'

require_relative 'network/transreceiver'

module Bitcoin

  MAINNET_PORT = 8333
  PROTOCOL_VERSION = 70001
  NODE_NETWORK = 1

  class ConnectionHandler < EventMachine::Connection
    def initialize peer_searcher
      @transreceiver = Bitcoin::Transreceiver.new(self)
      @peer_searcher = peer_searcher
      @host = peer_searcher.random_address
      @port = Bitcoin::MAINNET_PORT
      @sockaddr = [@port, @host]
      @connected = false
    end

    def post_init
      EventMachine::schedule { handshake_begin }
    end

    def receive_data data
      @transreceiver.receive_packets(data)
    end

    def unbind
      puts "Disconnected from #{@host}"
      @peer_searcher.next_attempt
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

    def handshake_complete
      puts "Connected successfully!"
      @connected = true
      exit
    end
  end
end

module Bitcoin
  class DeadSeed < StandardError; end

  class PeerSearcher
    SEEDS = ["seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "dnsseed.bitcoin.dashjr.org", "bitseed.xf2.org", "dnsseed.webbtc.com"]

    attr_reader :random_address

    def initialize
      @all_seeds = SEEDS.dup
      @random_seed = nil
      @all_addresses = nil
      @random_address = nil
    end

    def first_attempt
      find_random_peer
      puts "Attempting to connect to #{@random_address}"
      EventMachine::connect(@random_address.to_s, Bitcoin::MAINNET_PORT, Bitcoin::ConnectionHandler, self)
    end

    def next_attempt
      @all_addresses.delete(@random_address)
      if @all_addresses.empty?
        @all_seeds.delete(@random_seed)
        find_random_peer
      else
        @random_address = @all_addresses.sample
      end
      puts "Attempting to connect to #{@random_address}"
      EventMachine::connect(@random_address.to_s, Bitcoin::MAINNET_PORT, Bitcoin::ConnectionHandler, self)
    end

    private

    def find_address seed
      @all_addresses = Resolv::DNS.new.getaddresses(seed)
      if @all_addresses.empty?
        raise Bitcoin::DeadSeed.new
      else
        @all_addresses.sample
      end
    end

    def find_random_peer
      if @all_seeds.empty?
        puts "All seeds are dead. Exiting..."
        exit
      end
      @random_seed = @all_seeds.sample
      puts "Attempting to query seed: #{@random_seed}"
      begin
        @random_address = find_address @random_seed
      rescue DeadSeed
        puts "Seed: #{@random_seed} is dead. Trying again..."
        @all_seeds.delete(@random_peer)
        find_random_peer
      end
    end
  end
end

# Establishes client connection with peers
EventMachine::run do
  peer_searcher = Bitcoin::PeerSearcher.new
  peer_searcher.first_attempt
end
