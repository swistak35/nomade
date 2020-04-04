require "net/https"
require "json"

module Nomade
  class Http
    def initialize(nomad_endpoint)
      @nomad_endpoint = nomad_endpoint
    end

    def job_index_request(search_prefix = nil)
      search_prefix = if search_prefix
        "?prefix=#{search_prefix}"
      else
        ""
      end
      path = "/v1/jobs#{search_prefix}"
      res_body = _request(:get, path, total_retries: 3)
      return JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def evaluation_request(evaluation_id)
      res_body = _request(:get, "/v1/evaluation/#{evaluation_id}", total_retries: 3)
      return JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def allocations_from_evaluation_request(evaluation_id)
      res_body = _request(:get, "/v1/evaluation/#{evaluation_id}/allocations", total_retries: 3)
      return JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def deployment_request(deployment_id)
      res_body = _request(:get, "/v1/deployment/#{deployment_id}", total_retries: 3)

      return JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def check_if_job_exists?(nomad_job)
      jobs = job_index_request(nomad_job.job_name)
      jobs.map{|job| job["ID"]}.include?(nomad_job.job_name)
    end

    def create_job(nomad_job)
      req_body = JSON.generate({"Job" => nomad_job.configuration(:hash)})
      res_body = _request(:post, "/v1/jobs", body: req_body)

      return JSON.parse(res_body)["EvalID"]
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def update_job(nomad_job)
      req_body = JSON.generate({"Job" => nomad_job.configuration(:hash)})
      res_body = _request(:post, "/v1/job/#{nomad_job.job_name}", body: req_body)

      return JSON.parse(res_body)["EvalID"]
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def stop_job(nomad_job, purge = false)
      path = if purge
        "/v1/job/#{nomad_job.job_name}?purge=true"
      else
        "/v1/job/#{nomad_job.job_name}"
      end

      res_body = _request(:delete, path)
      return JSON.parse(res_body)["EvalID"]
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def promote_deployment(deployment_id)
      req_body = {
        "DeploymentID" => deployment_id,
        "All" => true,
      }.to_json
      res_body = _request(:post, "/v1/deployment/promote/#{deployment_id}", body: req_body)

      return true
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def fail_deployment(deployment_id)
      res_body = _request(:post, "/v1/deployment/fail/#{deployment_id}")
      return true
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def get_allocation_logs(allocation_id, task_name, logtype)
      res_body = _request(:get, "/v1/client/fs/logs/#{allocation_id}?task=#{task_name}&type=#{logtype}&plain=true&origin=end",
        total_retries: 3,
        expected_content_type: "text/plain",
      )
      return res_body.gsub(/\e\[\d+m/, '')
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def capacity_plan_job(nomad_job)
      plan_output = plan_job(nomad_job)

      if plan_output["FailedTGAllocs"]
        raise Nomade::FailedTaskGroupPlan.new("Failed to plan groups: #{plan_output["FailedTGAllocs"].keys.join(",")}")
      end

      true
    rescue Nomade::FailedTaskGroupPlan => e
      raise
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def convert_hcl_to_json(job_hcl)
      req_body = JSON.generate({
        "JobHCL": job_hcl,
        "Canonicalize": false,
      })
      res_body = _request(:post, "/v1/jobs/parse", body: req_body, total_retries: 3)
      res_body
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def plan_job(nomad_job)
      req_body = JSON.generate({"Job" => nomad_job.configuration(:hash)})
      res_body = _request(:post, "/v1/job/#{nomad_job.job_name}/plan", body: req_body)

      JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    def dispatch_job(nomad_job, payload_data: nil, payload_metadata: nil)
      if payload_metadata.class == Array && payload_metadata.empty?
        payload_metadata = nil
      end

      req_body = JSON.generate({
        "Payload": payload_data,
        "Meta": payload_metadata,
      }.delete_if { |k, v| v.nil? })

      res_body = _request(:post, "/v1/job/#{nomad_job.job_name}/dispatch", body: req_body)
      JSON.parse(res_body)
    rescue StandardError => e
      Nomade.logger.fatal "HTTP Request failed (#{e.message})"
      raise
    end

    private

    def _request(request_type, path, body: nil, total_retries: 0, expected_content_type: "application/json")
      uri = URI("#{@nomad_endpoint}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      if @nomad_endpoint.include?("https://")
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      req = case request_type
      when :get
        Net::HTTP::Get.new(uri)
      when :post
        Net::HTTP::Post.new(uri)
      when :delete
        Net::HTTP::Delete.new(uri)
      else
        raise "#{request_type} not supported"
      end
      req.add_field "Content-Type", "application/json"
      req.body = body if body

      res = begin
        retries ||= 0
        http.request(req)
      rescue Timeout::Error, Errno::ETIMEDOUT, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, SocketError
        if retries < total_retries
          retries += 1
          sleep 1
          retry
        else
          raise
        end
      end

      raise if res.code != "200"
      if res.content_type != expected_content_type
        # Sometimes the log endpoint doesn't set content_type on no content
        # https://github.com/hashicorp/nomad/issues/7264
        if res.content_type == nil && expected_content_type == "text/plain"
          # don't raise
        else
          raise
        end
      end

      res.body
    end

  end
end
