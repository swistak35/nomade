module Nomade
  class Deployer
    attr_reader :nomad_job

    def initialize(nomad_endpoint, opts = {})
      @nomad_endpoint = nomad_endpoint
      @http = Nomade::Http.new(@nomad_endpoint)
      @job_builder = Nomade::JobBuilder.new(@http)
      @logger = opts.fetch(:logger, Nomade.logger)

      @timeout = Time.now.utc + 60 * 3 # minutes

      @on_success = opts.fetch(:on_success, [])
      @on_failure = opts.fetch(:on_failure, [])
      @on_failure << method(:print_errors)

      self
    end

    def init_job(template_file, image_full_name, template_variables = {})
      @nomad_job = @job_builder.build(template_file, image_full_name, template_variables)
      @evaluation_id = nil
      @deployment_id = nil

      self
    end

    def deploy!
      _plan
      _deploy
    rescue Nomade::NoModificationsError => e
      call_failure_handlers ["No modifications to make, exiting!"]
      exit(0)
    rescue Nomade::GeneralError => e
      call_failure_handlers [e.message, "GeneralError hit, exiting!"]
      exit(1)
    rescue Nomade::PlanningError => e
      call_failure_handlers ["Couldn't make a plan, maybe a bad connection to Nomad server, exiting!"]
      exit(2)
    rescue Nomade::AllocationFailedError => e
      call_failure_handlers ["Allocation failed with errors, exiting!"]
      exit(3)
    rescue Nomade::UnsupportedDeploymentMode => e
      call_failure_handlers [e.message, "Deployment failed with errors, exiting!"]
      exit(4)
    rescue Nomade::FailedTaskGroupPlan => e
      call_failure_handlers [e.message, "Couldn't plan correctly, exiting!"]
      exit(5)
    end

    def stop!(purge = false)
      @http.stop_job(@nomad_job, purge)
    end

    private

    def call_failure_handlers(messages)
      @on_failure.each do |failure_handler|
        failure_handler.call(messages)
      end
    end

    def print_errors(errors)
      errors.each do |error|
        @logger.warn(error)
      end
    end

    def _plan
      @http.capacity_plan_job(@nomad_job)
    end

    def _deploy
      @logger.info "Deploying #{@nomad_job.job_name} (#{@nomad_job.job_type}) with #{@nomad_job.image_name_and_version}"
      @logger.info "URL: #{@nomad_endpoint}/ui/jobs/#{@nomad_job.job_name}"

      @logger.info "Checking cluster for connectivity and capacity.."
      @http.plan_job(@nomad_job)

      @evaluation_id = if @http.check_if_job_exists?(@nomad_job)
        @logger.info "Updating existing job"
        @http.update_job(@nomad_job)
      else
        @logger.info "Creating new job"
        @http.create_job(@nomad_job)
      end

      @logger.info "EvaluationID: #{@evaluation_id}"
      @logger.info "#{@evaluation_id} Waiting until evaluation is complete"
      eval_status = nil
      while(eval_status != "complete") do
        evaluation = @http.evaluation_request(@evaluation_id)
        @deployment_id ||= evaluation["DeploymentID"]
        eval_status = evaluation["Status"]
        @logger.info "."
        sleep(1)
      end

      @logger.info "Waiting until allocations are complete"
      case @nomad_job.job_type
      when "service"
        service_deploy
      when "batch"
        batch_deploy
      else
        raise Nomade::GeneralError.new("Job-type '#{@nomad_job.job_type}' not implemented")
      end
    rescue Nomade::AllocationFailedError => e
      e.allocations.each do |allocation|
        allocation["TaskStates"].sort.each do |task_name, task_data|
          pretty_state = Nomade::Decorator.task_state_decorator(task_data["State"], task_data["Failed"])

          @logger.info ""
          @logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"
          unless task_data["Failed"]
            @logger.info "Task \"#{task_name}\" was succesfully run, skipping log-printing because it isn't relevant!"
            next
          end

          stdout = @http.get_allocation_logs(allocation["ID"], task_name, "stdout")
          if stdout != ""
            @logger.info
            @logger.info "stdout:"
            stdout.lines do |logline|
              @logger.info(logline.strip)
            end
          end

          stderr = @http.get_allocation_logs(allocation["ID"], task_name, "stderr")
          if stderr != ""
            @logger.info
            @logger.info "stderr:"
            stderr.lines do |logline|
              @logger.info(logline.strip)
            end
          end

          task_data["Events"].each do |event|
            event_type = event["Type"]
            event_time = Time.at(event["Time"]/1000/1000000).utc
            event_message = event["DisplayMessage"]

            event_details = if event["Details"].any?
              dts = event["Details"].map{|k,v| "#{k}: #{v}"}.join(", ")
              "(#{dts})"
            end

            @logger.info "[#{event_time}] #{event_type}: #{event_message} #{event_details}"
          end
        end
      end

      raise
    end

    def service_deploy
      @logger.info "Waiting until tasks are placed"
      @logger.info ".. deploy timeout is #{@timeout}"

      json = @http.deployment_request(@deployment_id)
      @logger.info "#{json["JobID"]} version #{json["JobVersion"]}"

      need_manual_promotion = json["TaskGroups"].values.any?{|tg| tg["DesiredCanaries"] > 0 && tg["AutoPromote"] == false}
      need_manual_rollback  = json["TaskGroups"].values.any?{|tg| tg["DesiredCanaries"] > 0 && tg["AutoRevert"] == false}

      manual_work_required = case [need_manual_promotion, need_manual_rollback]
      when [true, true]
        @logger.info "Job needs manual promotion/rollback, we'll take care of that!"
        true
      when [false, false]
        @logger.info "Job manages its own promotion/rollback, we will just monitor in a hands-off mode!"
        false
      when [false, true]
        raise UnsupportedDeploymentMode.new("Unsupported deployment-mode, manual-promotion=#{need_manual_promotion}, manual-rollback=#{need_manual_rollback}")
      when [true, false]
        raise UnsupportedDeploymentMode.new("Unsupported deployment-mode, manual-promotion=#{need_manual_promotion}, manual-rollback=#{need_manual_rollback}")
      end

      announced_completed = []
      promoted = false
      failed = false
      succesful_deployment = nil
      while(succesful_deployment == nil) do
        json = @http.deployment_request(@deployment_id)

        json["TaskGroups"].each do |task_name, task_data|
          next if announced_completed.include?(task_name)

          desired_canaries = task_data["DesiredCanaries"]
          desired_total = task_data["DesiredTotal"]
          placed_allocations = task_data["PlacedAllocs"]
          healthy_allocations = task_data["HealthyAllocs"]
          unhealthy_allocations = task_data["UnhealthyAllocs"]

          if manual_work_required
            @logger.info "#{json["ID"]} #{task_name}: #{healthy_allocations}/#{desired_canaries}/#{desired_total} (Healthy/WantedCanaries/Total)"
            announced_completed << task_name if healthy_allocations == desired_canaries
          else
            @logger.info "#{json["ID"]} #{task_name}: #{healthy_allocations}/#{desired_total} (Healthy/Total)"
            announced_completed << task_name if healthy_allocations == desired_total
          end
        end

        if manual_work_required
          if json["Status"] == "failed"
            @logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = false
          end

          if succesful_deployment == nil && Time.now.utc > @timeout
            @logger.info "Timeout hit, rolling back deploy!"
            @http.fail_deployment(@deployment_id)
            succesful_deployment = false
          end

          if succesful_deployment == nil && json["TaskGroups"].values.all?{|tg| tg["HealthyAllocs"] >= tg["DesiredCanaries"]}
            if !promoted
              random_linger = rand(8..28)
              @logger.info "Lingering around for #{random_linger} seconds before deployment.."
              sleep(random_linger)

              @logger.info "Promoting #{@deployment_id} (version #{json["JobVersion"]})"
              @http.promote_deployment(@deployment_id)
              promoted = true
              @logger.info ".. promoted!"
            else
              if json["Status"] == "successful"
                succesful_deployment = true
              else
                @logger.info "Waiting for promotion to complete #{@deployment_id} (version #{json["JobVersion"]})"
              end
            end
          end
        else
          case json["Status"]
          when "running"
            # no-op
          when "failed"
            @logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = false
          when "successful"
            @logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = true
          end
        end

        sleep 5 if succesful_deployment == nil
      end

      if succesful_deployment
        @logger.info ""
        @logger.info "#{@deployment_id} (version #{json["JobVersion"]}) was succesfully deployed!"
      else
        @logger.warn ""
        @logger.warn "#{@deployment_id} (version #{json["JobVersion"]}) deployment _failed_!"
      end
    end

    def batch_deploy
      alloc_status = nil
      announced_dead = []

      while(alloc_status != true) do
        allocations = @http.allocations_from_evaluation_request(@evaluation_id)

        allocations.each do |allocation|
          allocation["TaskStates"].sort.each do |task_name, task_data|
            full_task_address = [allocation["ID"], allocation["Name"], task_name].join(" ")
            pretty_state = Nomade::Decorator.task_state_decorator(task_data["State"], task_data["Failed"])

            unless announced_dead.include?(full_task_address)
              @logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"

              if task_data["State"] == "dead"
                announced_dead << full_task_address
              end
            end
          end
        end

        tasks           = get_tasks(allocations)
        upcoming_tasks  = get_upcoming_tasks(tasks)
        succesful_tasks = get_succesful_tasks(tasks)
        failed_tasks    = get_failed_tasks(tasks)

        if upcoming_tasks.size == 0
          if failed_tasks.any?
            raise Nomade::AllocationFailedError.new(@evaluation_id, allocations)
          end

          @logger.info "Deployment complete"

          allocations.each do |allocation|
            allocation["TaskStates"].sort.each do |task_name, task_data|
              pretty_state = Nomade::Decorator.task_state_decorator(task_data["State"], task_data["Failed"])

              @logger.info ""
              @logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"

              stdout = @http.get_allocation_logs(allocation["ID"], task_name, "stdout")
              if stdout != ""
                @logger.info
                @logger.info "stdout:"
                stdout.lines do |logline|
                  @logger.info(logline.strip)
                end
              end

              stderr = @http.get_allocation_logs(allocation["ID"], task_name, "stderr")
              if stderr != ""
                @logger.info
                @logger.info "stderr:"
                stderr.lines do |logline|
                  @logger.info(logline.strip)
                end
              end
            end
          end

          alloc_status = true
        end

        sleep(1)
      end
    end

    # Task-helpers
    def get_tasks(allocations)
      [].tap do |it|
        allocations.each do |allocation|
          allocation["TaskStates"].sort.each do |task_name, task_data|
            it << {
              "Name" => task_name,
              "Allocation" => allocation,
            }.merge(task_data)
          end
        end
      end
    end

    def get_upcoming_tasks(tasks)
      [].tap do |it|
        tasks.each do |task|
          if ["pending", "running"].include?(task["State"])
            it << task
          end
        end
      end
    end

    def get_succesful_tasks(tasks)
      [].tap do |it|
        tasks.each do |task|
          if task["State"] == "dead" && task["Failed"] == false
            it << task
          end
        end
      end
    end

    def get_failed_tasks(tasks)
      [].tap do |it|
        tasks.each do |task|
          if task["State"] == "dead" && task["Failed"] == true
            it << task
          end
        end
      end
    end

  end
end
