RSpec.describe "Deploy hooks" do
  context "for services" do
    it "should run deploy hooks on succesful deploy" do
      nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
      image_name = "stefanscherer/whoami:2.0.0"

      $start_proc_arr01 = []
      $start_proc_arr02 = []
      $succesful_proc_arr = []
      $failure_proc_arr = []

      start01 = lambda { |hook_type, nomad_job, messages|
        $start_proc_arr01 << [hook_type, nomad_job, messages]
      }

      start02 = Proc.new { |hook_type, nomad_job, messages|
        $start_proc_arr02 << [hook_type, nomad_job, messages]
      }

      succesful = Proc.new { |hook_type, nomad_job, messages|
        $succesful_proc_arr << [hook_type, nomad_job, messages]
      }

      failure = lambda { |hook_type, nomad_job, messages|
        $failure_proc_arr << [hook_type, nomad_job, messages]
      }

      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start01)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start02)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FINISHED, succesful)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FAILED, failure)
        deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, default_job_vars.call)
        deployer.deploy!
      }.not_to raise_error

      expect($start_proc_arr01.count).to eq 1
      expect($start_proc_arr01.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($start_proc_arr02.count).to eq 1
      expect($start_proc_arr02.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($succesful_proc_arr.count).to eq 1
      expect($succesful_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_FINISHED

      expect($failure_proc_arr.count).to eq 0

      # Cleanup
      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, default_job_vars.call)
        deployer.stop!(true)
      }.not_to raise_error
      # Allow Nomad to clean up
      sleep(5)
    end

    it "should run deploy hooks on a failed deploy" do
      nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
      image_name = "stefanscherer/whoami:2.0.0"

      $start_proc_arr = []
      $succesful_proc_arr = []
      $failure_proc_arr = []

      start = lambda { |hook_type, nomad_job, messages|
        $start_proc_arr << [hook_type, nomad_job, messages]
      }

      succesful = Proc.new { |hook_type, nomad_job, messages|
        $succesful_proc_arr << [hook_type, nomad_job, messages]
      }

      failure = lambda { |hook_type, nomad_job, messages|
        $failure_proc_arr << [hook_type, nomad_job, messages]
      }

      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FINISHED, succesful)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FAILED, failure)
        deployer.init_job("spec/jobfiles/whoami_fail.hcl.erb", image_name, default_job_vars.call)
        deployer.deploy!
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(6)
      end

      expect($start_proc_arr.count).to eq 1
      expect($start_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($succesful_proc_arr.count).to eq 0

      expect($failure_proc_arr.count).to eq 1
      expect($failure_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_FAILED

      # Cleanup
      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, default_job_vars.call)
        deployer.stop!(true)
      }.not_to raise_error
      # Allow Nomad to clean up
      sleep(5)
    end
  end

  context "for batch-jobs" do
    it "should run deploy hooks on succesful deploy" do
      nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
      image_name = "ubuntu:18.04"

      $start_proc_arr01 = []
      $start_proc_arr02 = []
      $succesful_proc_arr = []
      $failure_proc_arr = []

      start01 = lambda { |hook_type, nomad_job, messages|
        $start_proc_arr01 << [hook_type, nomad_job, messages]
      }

      start02 = Proc.new { |hook_type, nomad_job, messages|
        $start_proc_arr02 << [hook_type, nomad_job, messages]
      }

      succesful = Proc.new { |hook_type, nomad_job, messages|
        $succesful_proc_arr << [hook_type, nomad_job, messages]
      }

      failure = lambda { |hook_type, nomad_job, messages|
        $failure_proc_arr << [hook_type, nomad_job, messages]
      }

      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start01)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start02)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FINISHED, succesful)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FAILED, failure)
        deployer.init_job("spec/jobfiles/batchjob_example.hcl.erb", image_name, default_job_vars.call)
        deployer.deploy!
      }.not_to raise_error

      expect($start_proc_arr01.count).to eq 1
      expect($start_proc_arr01.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($start_proc_arr02.count).to eq 1
      expect($start_proc_arr02.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($succesful_proc_arr.count).to eq 1
      expect($succesful_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_FINISHED

      expect($failure_proc_arr.count).to eq 0

      # Cleanup
      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.init_job("spec/jobfiles/batchjob_example.hcl.erb", image_name, default_job_vars.call)
        deployer.stop!(true)
      }.not_to raise_error
      # Allow Nomad to clean up
      sleep(5)
    end

    it "should run deploy hooks on a failed deploy" do
      nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
      image_name = "ubuntu:18.04"

      $start_proc_arr = []
      $succesful_proc_arr = []
      $failure_proc_arr = []

      start = lambda { |hook_type, nomad_job, messages|
        $start_proc_arr << [hook_type, nomad_job, messages]
      }

      succesful = Proc.new { |hook_type, nomad_job, messages|
        $succesful_proc_arr << [hook_type, nomad_job, messages]
      }

      failure = lambda { |hook_type, nomad_job, messages|
        $failure_proc_arr << [hook_type, nomad_job, messages]
      }

      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.add_hook(Nomade::Hooks::DEPLOY_RUNNING, start)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FINISHED, succesful)
        deployer.add_hook(Nomade::Hooks::DEPLOY_FAILED, failure)
        deployer.init_job("spec/jobfiles/batchjob_example_fail.hcl.erb", image_name, default_job_vars.call)
        deployer.deploy!
      }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(3)
      end

      expect($start_proc_arr.count).to eq 1
      expect($start_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_RUNNING

      expect($succesful_proc_arr.count).to eq 0

      expect($failure_proc_arr.count).to eq 1
      expect($failure_proc_arr.first[0]).to eq Nomade::Hooks::DEPLOY_FAILED

      # Cleanup
      expect {
        deployer = Nomade::Deployer.new(nomad_endpoint, logger: $logger)
        deployer.init_job("spec/jobfiles/batchjob_example_fail.hcl.erb", image_name, default_job_vars.call)
        deployer.stop!(true)
      }.not_to raise_error
      # Allow Nomad to clean up
      sleep(5)
    end
  end
end
