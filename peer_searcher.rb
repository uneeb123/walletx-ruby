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
    end

    def next_attempt
      @all_addresses.delete(@random_address)
      if @all_addresses.empty?
        @all_seeds.delete(@random_seed)
        find_random_peer
      else
        @random_address = @all_addresses.sample
      end
    end

    private

    def find_address seed
      begin
        @all_addresses = Resolv::DNS.new.getaddresses(seed)
      rescue Errno::ECONNREFUSED
        raise Bitcoin::DeadSeed.new
      end
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
