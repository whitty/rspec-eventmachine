module RSpec::EM
  module FakeClock
    
    def clock
      API
    end
    
    module API
      STUBBED_METHODS = [:add_timer, :add_periodic_timer, :cancel_timer]

      def self.stub()
        stub_with_time(nil)
      end

      def self.stub_with_time(start_time)
        FakeClock.reset(start_time)
        STUBBED_METHODS.each do |method_name|
          RSpec::Mocks.allow_message(EventMachine, method_name, &FakeClock.method(method_name))
        end
        RSpec::Mocks.allow_message(Time, :now, &FakeClock.method(:now))
      end

      def self.reset
        FakeClock.reset
      end
      
      def self.tick(seconds)
        FakeClock.tick(seconds)
      end
    end
    
    class Schedule < SortedSet
      def next_scheduled_at(time)
        find { |timeout| timeout.time <= time }
      end
    end
    
    class Timeout
      include Comparable
      
      attr_accessor :time
      attr_reader :block, :interval, :repeat
      
      def initialize(block, interval, repeat)
        @block    = block
        @interval = interval
        @repeat   = repeat
      end
      
      def <=>(other)
        @time - other.time
      end
    end
    
    def self.now
      @call_time
    end
    
    def self.reset(time = nil)
      @current_time = time || Time.now
      @call_time    = @current_time
      @schedule     = Schedule.new
    end
    
    def self.tick(seconds)
      @current_time += seconds
      while timeout = @schedule.next_scheduled_at(@current_time)
        run(timeout)
      end
      @call_time = @current_time
    end
    
    def self.run(timeout)
      @call_time = timeout.time
      timeout.block.call
      
      if timeout.repeat
        timeout.time += timeout.interval
        @schedule = Schedule.new(@schedule)
      else
        clear_timeout(timeout)
      end
    end
    
    def self.timer(block, seconds, repeat)
      timeout = Timeout.new(block, seconds, repeat)
      timeout.time = @call_time + seconds
      @schedule.add(timeout)
      timeout
    end
    
    def self.add_timer(seconds, proc = nil, &block)
      timer(block || proc, seconds, false)
    end
    
    def self.add_periodic_timer(seconds, proc = nil, &block)
      timer(block || proc, seconds, true)
    end
    
    def self.cancel_timer(timeout)
      clear_timeout(timeout)
    end
    
    def self.clear_timeout(timeout)
      @schedule.delete(timeout)
    end
    
  end
end

