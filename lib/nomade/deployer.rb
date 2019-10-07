module Nomade
  class Deployer
    def initialize(nomad_endpoint, nomad_job)
      @nomad_job = nomad_job
      @evaluation_id = nil
      @deployment_id = nil
      @timeout = Time.now.utc + 60 * 9 # minutes
      @http = Nomade::Http.new(nomad_endpoint)
    end

    def deploy!
      deploy
    rescue Nomade::NoModificationsError => e
      Nomade.logger.warn "No modifications to make, exiting!"
      exit(0)
    rescue Nomade::GeneralError => e
      Nomade.logger.warn e.message
      Nomade.logger.warn "GeneralError hit, exiting!"
      exit(1)
    rescue Nomade::PlanningError => e
      Nomade.logger.warn "Couldn't make a plan, maybe a bad connection to Nomad server, exiting!"
      exit(2)
    rescue Nomade::AllocationFailedError => e
      Nomade.logger.warn "Allocation failed with errors, exiting!"
      exit(3)
    rescue Nomade::UnsupportedDeploymentMode => e
      Nomade.logger.warn e.message
      Nomade.logger.warn "Deployment failed with errors, exiting!"
      exit(4)
    end

    private

    def deploy
      Nomade.logger.info "Deploying #{@nomad_job.job_name} (#{@nomad_job.job_type}) with #{@nomad_job.image_name_and_version}"

      Nomade.logger.info "Checking cluster for connectivity and capacity.."
      @http.plan_job(@nomad_job)

      @evaluation_id = if @http.check_if_job_exists?(@nomad_job)
        Nomade.logger.info "Updating existing job"
        @http.update_job(@nomad_job)
      else
        Nomade.logger.info "Creating new job"
        @http.create_job(@nomad_job)
      end

      Nomade.logger.info "EvaluationID: #{@evaluation_id}"
      Nomade.logger.info "#{@evaluation_id} Waiting until evaluation is complete"
      eval_status = nil
      while(eval_status != "complete") do
        evaluation = @http.evaluation_request(@evaluation_id)
        @deployment_id ||= evaluation["DeploymentID"]
        eval_status = evaluation["Status"]
        Nomade.logger.info "."
        sleep(1)
      end

      Nomade.logger.info "Waiting until allocations are complete"
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

          Nomade.logger.info ""
          Nomade.logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"
          unless task_data["Failed"]
            Nomade.logger.info "Task \"#{task_name}\" was succesfully run, skipping log-printing because it isn't relevant!"
            next
          end

          stdout = @http.get_allocation_logs(allocation["ID"], task_name, "stdout")
          if stdout != ""
            Nomade.logger.info
            Nomade.logger.info "stdout:"
            stdout.lines do |logline|
              Nomade.logger.info(logline.strip)
            end
          end

          stderr = @http.get_allocation_logs(allocation["ID"], task_name, "stderr")
          if stderr != ""
            Nomade.logger.info
            Nomade.logger.info "stderr:"
            stderr.lines do |logline|
              Nomade.logger.info(logline.strip)
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

            Nomade.logger.info "[#{event_time}] #{event_type}: #{event_message} #{event_details}"
          end
        end
      end

      raise
    end

    def service_deploy
      Nomade.logger.info "Waiting until tasks are placed"
      Nomade.logger.info ".. deploy timeout is #{@timeout}"

      json = @http.deployment_request(@deployment_id)
      Nomade.logger.info "#{json["JobID"]} version #{json["JobVersion"]}"

      need_manual_promotion = json["TaskGroups"].values.any?{|tg| tg["DesiredCanaries"] > 0 && tg["AutoPromote"] == false}
      need_manual_rollback  = json["TaskGroups"].values.any?{|tg| tg["DesiredCanaries"] > 0 && tg["AutoRevert"] == false}

      manual_work_required = case [need_manual_promotion, need_manual_rollback]
      when [true, true]
        Nomade.logger.info "Job needs manual promotion/rollback, we'll take care of that!"
        true
      when [false, false]
        Nomade.logger.info "Job manages its own promotion/rollback, we will just monitor in a hands-off mode!"
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
            Nomade.logger.info "#{json["ID"]} #{task_name}: #{healthy_allocations}/#{desired_canaries}/#{desired_total} (Healthy/WantedCanaries/Total)"
            announced_completed << task_name if healthy_allocations == desired_canaries
          else
            Nomade.logger.info "#{json["ID"]} #{task_name}: #{healthy_allocations}/#{desired_total} (Healthy/Total)"
            announced_completed << task_name if healthy_allocations == desired_total
          end
        end

        if manual_work_required
          if json["Status"] == "failed"
            Nomade.logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = false
          end

          if succesful_deployment == nil && Time.now.utc > @timeout
            Nomade.logger.info "Timeout hit, rolling back deploy!"
            @http.fail_deployment(@deployment_id)
            succesful_deployment = false
          end

          if succesful_deployment == nil && json["TaskGroups"].values.all?{|tg| tg["HealthyAllocs"] >= tg["DesiredCanaries"]}
            if !promoted
              Nomade.logger.info "Promoting #{@deployment_id} (version #{json["JobVersion"]})"
              @http.promote_deployment(@deployment_id)
              promoted = true
              Nomade.logger.info ".. promoted!"
            else
              if json["Status"] == "successful"
                succesful_deployment = true
              else
                Nomade.logger.info "Waiting for promotion to complete #{@deployment_id} (version #{json["JobVersion"]})"
              end
            end
          end
        else
          case json["Status"]
          when "running"
            # no-op
          when "failed"
            Nomade.logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = false
          when "successful"
            Nomade.logger.info "#{json["Status"]}: #{json["StatusDescription"]}"
            succesful_deployment = true
          end
        end

        sleep 10 if succesful_deployment == nil
      end

      if succesful_deployment
        Nomade.logger.info ""
        Nomade.logger.info "#{@deployment_id} (version #{json["JobVersion"]}) was succesfully deployed!"
      else
        Nomade.logger.warn ""
        Nomade.logger.warn "#{@deployment_id} (version #{json["JobVersion"]}) deployment _failed_!"
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
              Nomade.logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"

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

          Nomade.logger.info "Deployment complete"

          allocations.each do |allocation|
            allocation["TaskStates"].sort.each do |task_name, task_data|
              pretty_state = Nomade::Decorator.task_state_decorator(task_data["State"], task_data["Failed"])

              Nomade.logger.info ""
              Nomade.logger.info "#{allocation["ID"]} #{allocation["Name"]} #{task_name}: #{pretty_state}"

              stdout = @http.get_allocation_logs(allocation["ID"], task_name, "stdout")
              if stdout != ""
                Nomade.logger.info
                Nomade.logger.info "stdout:"
                stdout.lines do |logline|
                  Nomade.logger.info(logline.strip)
                end
              end

              stderr = @http.get_allocation_logs(allocation["ID"], task_name, "stderr")
              if stderr != ""
                Nomade.logger.info
                Nomade.logger.info "stderr:"
                stderr.lines do |logline|
                  Nomade.logger.info(logline.strip)
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
