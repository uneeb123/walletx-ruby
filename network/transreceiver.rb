require 'pp'

require_relative 'packing_helper'
require_relative 'parser'

module Bitcoin
  class Transreceiver
    MAGIC_HEAD = "\xF9\xBE\xB4\xD9"
    BINARY = Encoding.find('ASCII-8BIT')

    include PackingHelper

    def initialize connection_handler
      @connection_handler = connection_handler
      @parser = Bitcoin::Protocol::Parser.new(self)
    end

    # https://en.bitcoin.it/wiki/Protocol_documentation#version
    def transmit_version_message fields
      puts "Transmitting..."
      pp fields
      payload = [
        fields.values_at(:version, :services, :time).pack("VQQ"),
        Bitcoin::PackingHelper::pack_address_field(fields[:from]),
        Bitcoin::PackingHelper::pack_address_field(fields[:to]),
        fields.values_at(:nonce).pack("Q"),
        Bitcoin::PackingHelper::pack_var_string(fields[:user_agent]),
        fields.values_at(:last_block).pack("V"),
        Bitcoin::PackingHelper::pack_boolean(fields[:relay])
      ].join
      packet = pkt("version", payload)
      @connection_handler.send_data(packet)
    end

    def receive_packets data
      @parser.parse(data)
    end

    def receive_version_message fields
      puts "Receiving..."
      pp fields
      exit
    end

    private

    def pkt(command, payload)
      cmd      = command.ljust(12, "\x00")[0...12]
      length   = [payload.bytesize].pack("V")
      checksum = Digest::SHA256.digest(Digest::SHA256.digest(payload))[0...4]
      pkt      = "".force_encoding(BINARY)
      pkt << MAGIC_HEAD.force_encoding(BINARY) << cmd.force_encoding(BINARY) << length << checksum << payload.force_encoding(BINARY)
    end
  end
end
