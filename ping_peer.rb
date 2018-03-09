require 'eventmachine'

require_relative 'ping_controller'

# Establishes client connection with peers
EventMachine::run do
  Bitcoin::PingController.new
end
