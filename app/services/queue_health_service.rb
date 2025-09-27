# frozen_string_literal: true

class QueueHealthService
  Result = Struct.new(:adapter, :solid, :error, keyword_init: true)

  def self.snapshot
    adapter_name = begin
      ActiveJob::Base.queue_adapter.class.name
    rescue StandardError
      "unknown"
    end

    solid = {}
    error = nil
    if adapter_name.include?("Solid") || defined?(SolidQueue)
      begin
        solid[:available] = true
        # Try to get basic stats if SolidQueue models are present
        if defined?(SolidQueue) && SolidQueue.const_defined?(:Job)
          solid[:jobs] = SolidQueue::Job.count rescue nil
        end
        if defined?(SolidQueue) && SolidQueue.const_defined?(:Process)
          solid[:processes] = SolidQueue::Process.count rescue nil
        end
        if defined?(SolidQueue) && SolidQueue.const_defined?(:FailedExecution)
          solid[:failed] = SolidQueue::FailedExecution.count rescue nil
        end
      rescue StandardError => e
        error = e.message
      end
    end

    Result.new(adapter: adapter_name, solid: solid, error: error)
  end
end
