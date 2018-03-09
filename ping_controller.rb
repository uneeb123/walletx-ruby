require_relative 'controller'

module Bitcoin
  class PingController < Bitcoin::Controller
    # Connector is passed back to the controller
    def do_work connector
      connector.transreceiver.transmit_ping_message
    end
  end
end
