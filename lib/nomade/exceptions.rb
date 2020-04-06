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

  class DeploymentFailedError < StandardError;end

  class UnsupportedDeploymentMode < StandardError; end
  class FailedTaskGroupPlan < StandardError; end

  class DispatchWrongJobType < StandardError; end
  class DispatchNotParamaterized < StandardError; end

  class DispatchMetaDataFormattingError < StandardError; end
  class DispatchMissingMetaData < StandardError; end
  class DispatchUnknownMetaData < StandardError; end

  class DispatchMissingPayload < StandardError; end
  class DispatchPayloadNotAllowed < StandardError; end
  class DispatchPayloadUnknown < StandardError; end

  class HttpConnectionError < StandardError; end
  class HttpBadResponse < StandardError; end
  class HttpBadContentType < StandardError; end
end
