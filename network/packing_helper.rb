module Bitcoin
  module PackingHelper
    BINARY = Encoding.find('ASCII-8BIT')

    def self.pack_address_field(addr_str)
      host, port = addr_str.split(":")
      sockaddr = Socket.pack_sockaddr_in(port.to_i, host)
      port, host = sockaddr[2...4], sockaddr[4...8]
      [[1].pack("Q"), "\x00"*10, "\xFF\xFF",  host, port].map{|x| x.force_encoding(BINARY)}.join
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
  end
end
