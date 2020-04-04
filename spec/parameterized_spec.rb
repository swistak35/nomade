require 'spec_helper'

RSpec.describe "Parameterized jobs", order: :defined do
  context "metadata input validation" do
    before(:all) do
      @deployer = Nomade::Deployer.new(nomad_endpoint)
      @deployer.init_job("spec/jobfiles/parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
    end

    after(:all) do
      expect {
        @deployer.stop!(true)
      }.not_to raise_error

      # Allow Nomad to clean up
      sleep(5)
    end

    it "should register parameterized job" do
      expect {
        @deployer.deploy!
      }.not_to raise_error

      job_versions = job_versions(nomad_endpoint, "paramsleep")["Versions"]
      expect(job_versions.count).to eq 1

      first_job_version = job_versions.first
      expect(first_job_version["ParameterizedJob"]).to eq({"MetaOptional"=>["FIRST_NAME", "LAST_NAME"], "MetaRequired"=>["SLEEP_TIME"], "Payload"=>"optional"})
    end

    it "should not raise with correct metadata" do
      expect {
        @deployer.dispatch!(payload_metadata: {
          "SLEEP_TIME" => "10",
        })
      }.not_to raise_error
    end

    it "should raise with missing required metadata" do
      expect {
        @deployer.dispatch!(payload_metadata: {})
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(11)
      end
    end

    it "should raise with metadata not defined in job-file" do
      expect {
        @deployer.dispatch!(payload_metadata: {
          "SLEEP_TIME" => "10",
          "I_LOVE_MAKING_UP_MY_OWN_METADATA" => "1D10T",
        })
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(12)
      end
    end
  end

  context "payload input validation" do
    before(:all) do
      @deployer_required = Nomade::Deployer.new(nomad_endpoint)
      @deployer_required.init_job("spec/jobfiles/parameterized_required_payload_job.hcl.erb", "debian:buster", default_job_vars.call)

      @deployer_forbidden = Nomade::Deployer.new(nomad_endpoint)
      @deployer_forbidden.init_job("spec/jobfiles/parameterized_forbidden_payload_job.hcl.erb", "debian:buster", default_job_vars.call)
    end

    after(:all) do
      expect {
        @deployer_required.stop!(true)
      }.not_to raise_error

      expect {
        @deployer_forbidden.stop!(true)
      }.not_to raise_error

      # Allow Nomad to clean up
      sleep(5)
    end

    it "should register parameterized jobs" do
      expect {
        @deployer_required.deploy!
      }.not_to raise_error

      expect {
        @deployer_forbidden.deploy!
      }.not_to raise_error
    end

    it "should allow payload to be set and used" do
      expect {
        @deployer_required.dispatch!(payload_data: "BLARGHMASTER!")
      }.not_to raise_error
    end

    it "should raise when payload is required but not sent" do
      expect {
        @deployer_required.dispatch!
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(20)
      end
    end

    it "should raise when payload is forbidden but sent" do
      expect {
        @deployer_forbidden.dispatch!(payload_data: "BLARGHMASTER!")
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(21)
      end
    end
  end

  context "parameterized defaults" do
    before(:all) do
      @deployer = Nomade::Deployer.new(nomad_endpoint)
      @deployer.init_job("spec/jobfiles/parameterized_default_payload_job.hcl.erb", "debian:buster", default_job_vars.call)
    end

    after(:all) do
      expect {
        @deployer.stop!(true)
      }.not_to raise_error

      # Allow Nomad to clean up
      sleep(5)
    end

    it "should register parameterized job" do
      expect {
        @deployer.deploy!
      }.not_to raise_error
    end

    it "should allow payload to be set" do
      expect {
        @deployer.dispatch!(payload_data: "BLARGHMASTER!")
      }.not_to raise_error
    end
  end

  context "non-parameterized job" do
    before(:all) do
      @deployer = Nomade::Deployer.new(nomad_endpoint)
      @deployer.init_job("spec/jobfiles/no_parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
    end

    after(:all) do
      expect {
        @deployer.stop!(true)
      }.not_to raise_error

      # Allow Nomad to clean up
      sleep(5)
    end

    it "should register parameterized job" do
      expect {
        @deployer.deploy!
      }.not_to raise_error
    end

    it "should allow payload to be set" do
      expect {
        @deployer.dispatch!(payload_data: "BLARGHMASTER!")
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(31)
      end
    end
  end

  context "failing parameterized job" do
    before(:all) do
      @deployer = Nomade::Deployer.new(nomad_endpoint)
      @deployer.init_job("spec/jobfiles/parameterized_fail_job.hcl.erb", "debian:buster", default_job_vars.call)
    end

    after(:all) do
      expect {
        @deployer.stop!(true)
        sleep(5)
      }.not_to raise_error
    end

    it "should register parameterized job" do
      expect {
        @deployer.deploy!
      }.not_to raise_error
    end

    it "should raise on fail" do
      expect {
        @deployer.dispatch!(payload_data: "BLARGHMASTER!")
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(40)
      end
    end
  end

  context "hooks" do
    it "on success" do
      @deployer = Nomade::Deployer.new(nomad_endpoint)

      $parameterized_start_arr = []
      $parameterized_success_arr = []
      $parameterized_fail_arr = []

      dispatch_start = Proc.new { |hook_type, nomad_job, messages|
        $parameterized_start_arr << [hook_type, nomad_job, messages]
      }

      dispatch_succesful = Proc.new { |hook_type, nomad_job, messages|
        $parameterized_success_arr << [hook_type, nomad_job, messages]
      }

      dispatch_failure = lambda { |hook_type, nomad_job, messages|
        $parameterized_fail_arr << [hook_type, nomad_job, messages]
      }

      @deployer.add_hook(Nomade::Hooks::DISPATCH_RUNNING, dispatch_start)
      @deployer.add_hook(Nomade::Hooks::DISPATCH_FINISHED, dispatch_succesful)
      @deployer.add_hook(Nomade::Hooks::DISPATCH_FAILED, dispatch_failure)

      @deployer.init_job("spec/jobfiles/parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
      @deployer.deploy!

      expect {
        @deployer.dispatch!(payload_metadata: {"SLEEP_TIME" => "2"})
      }.not_to raise_error

      expect($parameterized_start_arr.size).to eq 1
      expect($parameterized_success_arr.size).to eq 1
      expect($parameterized_fail_arr.size).to eq 0

      expect($parameterized_start_arr.first[0]).to eq Nomade::Hooks::DISPATCH_RUNNING
      expect($parameterized_success_arr.first[0]).to eq Nomade::Hooks::DISPATCH_FINISHED
    ensure
      expect {
        @deployer.stop!(true)
        sleep(5)
      }.not_to raise_error
    end

    it "on failure" do
      @deployer = Nomade::Deployer.new(nomad_endpoint)

      $parameterized_start_arr = []
      $parameterized_success_arr = []
      $parameterized_fail_arr = []

      dispatch_start = Proc.new { |hook_type, nomad_job, messages|
        $parameterized_start_arr << [hook_type, nomad_job, messages]
      }

      dispatch_succesful = Proc.new { |hook_type, nomad_job, messages|
        $parameterized_success_arr << [hook_type, nomad_job, messages]
      }

      dispatch_failure = lambda { |hook_type, nomad_job, messages|
        $parameterized_fail_arr << [hook_type, nomad_job, messages]
      }

      @deployer.add_hook(Nomade::Hooks::DISPATCH_RUNNING, dispatch_start)
      @deployer.add_hook(Nomade::Hooks::DISPATCH_FINISHED, dispatch_succesful)
      @deployer.add_hook(Nomade::Hooks::DISPATCH_FAILED, dispatch_failure)

      @deployer.init_job("spec/jobfiles/parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
      @deployer.deploy!

      expect {
        @deployer.dispatch!
      }.to raise_error(SystemExit)

      expect($parameterized_start_arr.size).to eq 1
      expect($parameterized_success_arr.size).to eq 0
      expect($parameterized_fail_arr.size).to eq 1

      expect($parameterized_start_arr.first[0]).to eq Nomade::Hooks::DISPATCH_RUNNING
      expect($parameterized_fail_arr.first[0]).to eq Nomade::Hooks::DISPATCH_FAILED
    ensure
      expect {
        @deployer.stop!(true)
        sleep(5)
      }.not_to raise_error
    end

  end
end
