require 'spec_helper'

$logger = Yell.new do |l|
  l.adapter STDOUT, level: [:info, :warn]
  l.adapter STDERR, level: [:error, :fatal]
end

RSpec.describe Nomade do
  it "should deploy" do
    template_variables = {
      datacenter: "eu-test-1",
      dns: "172.17.0.1",
      environment_variables: {
        "DEPLOY_TIME"  => Time.now.utc.to_s,
      }
    }

    nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
    image_name = "stefanscherer/whoami:2.0.0"
    nomad_job_web = Nomade::Job.new("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)

    # First deploy for the first time
    expect { Nomade::Deployer.new(nomad_endpoint, nomad_job_web, logger: $logger).deploy! }.not_to raise_error

    # Deploy the exact same job
    expect { Nomade::Deployer.new(nomad_endpoint, nomad_job_web, logger: $logger).deploy! }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(0)
    end

    # Deploy changed job
    template_variables = {
      datacenter: "eu-test-1",
      dns: "172.17.0.1",
      environment_variables: {
        "DEPLOY_TIME"  => Time.now.utc.to_s,
      }
    }
    nomad_job_web = Nomade::Job.new("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)
    expect { Nomade::Deployer.new(nomad_endpoint, nomad_job_web, logger: $logger).deploy! }.not_to raise_error

    # Deploy crazy job
    nomad_job_web = Nomade::Job.new("spec/jobfiles/whoami_crazy.hcl.erb", image_name, template_variables)
    expect { Nomade::Deployer.new(nomad_endpoint, nomad_job_web, logger: $logger).deploy! }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(5)
    end

    # Cleanup
    Nomade::Deployer.new(nomad_endpoint, nomad_job_web, logger: $logger).stop!
  end

end
