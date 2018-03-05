# encoding: ascii-8bit

require 'eventmachine'
require 'socket'
require 'digest/sha2'

require_relative 'protocol/parser'

module Bitcoin

  PROTOCOL_VERSION = 70001
  NODE_NETWORK = 1

  class NetworkHelper
    MAGIC_HEAD = "\xF9\xBE\xB4\xD9"
    BINARY = Encoding.find('ASCII-8BIT')

    def self.pack_address_field(addr_str)
      host, port = addr_str.split(":")
      sockaddr = Socket.pack_sockaddr_in(port.to_i, host)
      port, host = sockaddr[2...4], sockaddr[4...8]
      [[1].pack("Q"), "\x00"*10, "\xFF\xFF",  host, port].join
    end

    def self.pack_var_string(payload)
      pack_var_int(payload.bytesize) + payload
    end

    def self.pack_var_int(i)
      if    i <  0xfd;                [      i].pack("C")
      elsif i <= 0xffff;              [0xfd, i].pack("Cv")
      elsif i <= 0xffffffff;          [0xfe, i].pack("CV")
      elsif i <= 0xffffffffffffffff;  [0xff, i].pack("CQ")
      else raise "int(#{i}) too large!"
      end
    end

    def self.pack_boolean(b)
      (b == true) ? [0xFF].pack("C") : [0x00].pack("C")
    end

    def self.create_version_message_payload fields
      payload = [
        fields.values_at(:version, :services, :time).pack("VQQ"),
        pack_address_field(fields[:from]),
        pack_address_field(fields[:to]),
        fields.values_at(:nonce).pack("Q"),
        pack_var_string(fields[:user_agent]),
        fields.values_at(:last_block).pack("V"),
        pack_boolean(fields[:relay])
      ].join
    end

    # https://en.bitcoin.it/wiki/Protocol_documentation#version
    def self.pkt(command, payload)
      cmd      = command.ljust(12, "\x00")[0...12]
      length   = [payload.bytesize].pack("V")
      checksum = Digest::SHA256.digest(Digest::SHA256.digest(payload))[0...4]
      pkt      = "".force_encoding(BINARY)
      pkt << MAGIC_HEAD.force_encoding(BINARY) << cmd.force_encoding(BINARY) << length << checksum << payload.force_encoding(BINARY)
    end
  end

  class ConnectionHandler < EventMachine::Connection
    def initialize host, port, connections
      @parser = Bitcoin::Protocol::Parser.new(self)
      @sockaddr = [port, host]
      @connections = connections
    end

    def post_init
      puts "connected with #{@sockaddr[1]}:#{@sockaddr[0]}"
      EventMachine::schedule { on_handshake_begin }
    end

    def receive_data data
      require 'pry'; binding.pry
      print "got data: #{data}"
      # @parser.parse(data)
    end

    def unbind
      puts "Disconnected"
      exit
    end

    # https://bitcoin.org/en/developer-reference#version
    def create_version_message
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
      payload = NetworkHelper.create_version_message_payload fields
      NetworkHelper.pkt("version", payload)
    end

    def on_handshake_begin
      packet = create_version_message
      require 'pry'; binding.pry
      send_data(packet)
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
