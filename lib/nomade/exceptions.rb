module Nomade
  class FormattingError < StandardError; end

  class GeneralError < StandardError; end
  class NoModificationsError < StandardError; end

  class AllocationFailedError < StandardError
    def initialize(evaluation_id, allocations)
      @evaluation_id = evaluation_id
      @allocations = allocations
    end
    attr_reader :evaluation_id, :allocations
  end
  class UnsupportedDeploymentMode < StandardError; end
  class FailedTaskGroupPlan < StandardError; end
end
