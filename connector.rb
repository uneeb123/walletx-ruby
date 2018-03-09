require_relative 'controller'
require_relative 'network/transreceiver'

module Bitcoin

  PROTOCOL_VERSION = 70001
  NODE_NETWORK = 1
  USER_AGENT = "/wallet-x:0.1/"

  class Connector < EventMachine::Connection
    attr_reader :transreceiver

    def initialize controller
      @transreceiver = Bitcoin::Transreceiver.new(self)
      @controller = controller
      @host = controller.host
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
      @controller.reconnect
    end

    def generate_nonce
      rand(0xffffffffffffffff)
    end

    def local_socket
      "127.0.0.1:#{Bitcoin::MAINNET_PORT}"
    end

    # https://bitcoin.org/en/developer-reference#version
    def version_message
      fields = {                                                                           
        version: PROTOCOL_VERSION,
        services: NODE_NETWORK,
        nonce: generate_nonce,
        from: local_socket,
        to: @sockaddr.reverse.join(":"),
        last_block: 0,
        time: Time.now.tv_sec,
        user_agent: USER_AGENT,
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
      do_work
    end

    def do_work
      @controller.do_work(self)
    end
  end
end
