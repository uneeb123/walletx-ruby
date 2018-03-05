require 'eventmachine'

module Bitcoin
  class ConnectionHandler < EventMachine::Connection

  end
end

SEEDS = ["seed.bitcoin.sipa.be", "dnsseed.bluematt.me", "dnsseed.bitcoin.dashjr.org", "bitseed.xf2.org", "dnsseed.webbtc.com"]
MAINNET_PORT = 8333

# Establishes client connection with peers
EventMachine::run do
  connections = []
  peer_host = Resolv::DNS.new.getaddresses(SEEDS.sample).map {|a| a.to_s}.sample

  EventMachine::connect(peer_host, MAINNET_PORT, Bitcoin::ConnectionHandler, MAINNET_PORT, connections)
end
