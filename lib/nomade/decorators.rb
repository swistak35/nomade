module Nomade
  class Decorator
    def self.task_state_decorator(task_state, task_failed)
      case task_state
      when "pending"
        "Pending"
      when "running"
        "Running"
      when "dead"
        if task_failed
          "Failed with errors!"
        else
          "Completed succesfully!"
        end
      end
    end
  end
end
