require 'resque'

module Resque
  def self.prune_dead_workers
    begin
      Worker.all.each { |worker| worker.prune_if_dead }
    rescue Exception => e
      p e
    end
  end

  class Worker
    def startup_with_heartbeat
      startup_without_heartbeat
      heart.run
    end
    alias startup_without_heartbeat startup
    alias startup startup_with_heartbeat

    def heart
      @heart ||= Heart.new(self)
    end

    def prune_if_dead
      if heart.last_beat_before?(5)
        log "Pruning Worker: #{to_s}"
        unregister_worker
      end
    end

    class Heart
      attr_reader :worker

      def initialize(worker)
        @worker = worker
      end

      def run
        Thread.new { loop { sleep(2) && beat! } }
      end

      def redis
        Resque.redis
      end

      def beat!
        redis.sadd(:workers, worker)
        redis.set("worker:#{worker}:heartbeat", Time.now.to_s)
      rescue Exception => e
        p e
      end

      def last_beat_before?(seconds)
        Time.parse(last_beat).utc < (Time.now.utc - seconds) rescue true
      end

      def last_beat
        Resque.redis.get("worker:#{worker}:heartbeat") || worker.started
      end
    end
  end
end
