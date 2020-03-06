require 'spec_helper'

RSpec.describe Nomade do
  it "should deploy" do
    template_variables = default_job_vars.call

    nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
    image_name = "stefanscherer/whoami:2.0.0"

    # First deploy for the first time
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)
      deployer.deploy!
    }.not_to raise_error

    # Deploy the exact same job
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)
      deployer.deploy!
    }.not_to raise_error

    # Deploy changed job
    template_variables = default_job_vars.call
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)
      deployer.deploy!
    }.not_to raise_error

    # Deploy crazy job
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami_crazy.hcl.erb", image_name, template_variables)
      deployer.deploy!
    }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(5)
    end

    # Cleanup
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, template_variables)
      deployer.stop!(true)
    }.not_to raise_error
    # Allow Nomad to clean up
    sleep(5)
  end

  it "should rollback if deploy is unhealthy" do
    nomad_endpoint = "http://nomadserver.vpn.kaspergrubbe.com:4646"
    image_name = "stefanscherer/whoami:2.0.0"

    # First deploy for the first time
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, default_job_vars.call)
      deployer.deploy!
    }.not_to raise_error

    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami_fail.hcl.erb", image_name, default_job_vars.call)
      deployer.deploy!
    }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(6)
    end

    # Verify job data
    version_data = job_versions(nomad_endpoint, "whoami-web")
    expect(version_data["Versions"].count).to eq 2

    first_deploy = version_data["Versions"].select{|version| version["Version"] == 0}.first
    expect(first_deploy["Stable"]).to eq true

    second_deploy = version_data["Versions"].select{|version| version["Version"] == 1}.first
    expect(second_deploy["Stable"]).to eq false

    # Cleanup
    expect {
      deployer = Nomade::Deployer.new(nomad_endpoint)
      deployer.init_job("spec/jobfiles/whoami.hcl.erb", image_name, default_job_vars.call)
      deployer.stop!(true)
    }.not_to raise_error
    # Allow Nomad to clean up
    sleep(5)
  end

end
