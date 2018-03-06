module Bitcoin
  module UnpackingHelper
    # var_int refers to https://en.bitcoin.it/wiki/Protocol_specification#Variable_length_integer and is what Satoshi called "CompactSize"
    # BitcoinQT has later added even more compact format called CVarInt to use in its local block storage. CVarInt is not implemented here.
    def self.unpack_var_int(payload)
      case payload.unpack("C")[0] # TODO add test cases
      when 0xfd; payload.unpack("xva*")
      when 0xfe; payload.unpack("xVa*")
      when 0xff; payload.unpack("xQa*") # TODO add little-endian version of Q
      else;      payload.unpack("Ca*")
      end
    end

    def self.unpack_var_int_from_io(io)
      uchar = io.read(1).unpack("C")[0]
      case uchar
      when 0xfd; io.read(2).unpack("v")[0]
      when 0xfe; io.read(4).unpack("V")[0]
      when 0xff; io.read(8).unpack("Q")[0]
      else;      uchar
      end
    end

    def self.unpack_var_string(payload)
      size, payload = unpack_var_int(payload)
      size > 0 ? (string, payload = payload.unpack("a#{size}a*")) : [nil, payload]
    end

    def self.unpack_relay_field(version, payload)
      ( version >= 70001 and payload ) ? Bitcoin::UnpackingHelper.unpack_boolean(payload) : [ true, nil ]
    end

    def self.unpack_boolean(payload)
      bdata, payload = payload.unpack("Ca*")
      [ (bdata == 0 ? false : true), payload ]
    end

    def self.unpack_address_field(payload)
      ip, port = payload.unpack("x8x12a4n")
      "#{ip.unpack("C*").join(".")}:#{port}"
    end
  end
end
