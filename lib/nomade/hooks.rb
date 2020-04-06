module Nomade
  module Hooks
    DEPLOY_RUNNING = Class.new
    DEPLOY_FINISHED = Class.new
    DEPLOY_FAILED = Class.new

    DISPATCH_RUNNING = Class.new
    DISPATCH_FINISHED = Class.new
    DISPATCH_FAILED = Class.new
  end
end
