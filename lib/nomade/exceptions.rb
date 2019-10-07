module Nomade
  class GeneralError < StandardError; end
  class NoModificationsError < StandardError; end
  class PlanningError < StandardError; end

  class AllocationFailedError < StandardError
    def initialize(evaluation_id, allocations)
      @evaluation_id = evaluation_id
      @allocations = allocations
    end
    attr_reader :evaluation_id, :allocations
  end
  class UnsupportedDeploymentMode < StandardError; end
end
