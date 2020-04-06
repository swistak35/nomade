require 'spec_helper'

RSpec.describe "Connection tests" do
  it "trigger Net::OpenTimeout: execution expired" do
    # According to http://en.wikipedia.org/wiki/Reserved_IP_addresses on reserved addresses,
    # there are 3 test networks intended for use in documentation only:
    # - 192.0.2.0/24
    # - 198.51.100.0/24
    # - 203.0.113.0/24
    deployer = Nomade::Deployer.new("http://198.51.100.1:4646")
    expect {
      deployer.init_job("spec/jobfiles/parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
    }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(7)
    end
  end

  it "trigger SocketError: Failed to open TCP connection to blarghIdonotexistlalalala:4646 (getaddrinfo: nodename nor servname provided, or not known)" do
    deployer = Nomade::Deployer.new("http://blarghIdonotexistlalalala:4646")
    expect {
      deployer.init_job("spec/jobfiles/parameterized_job.hcl.erb", "debian:buster", default_job_vars.call)
    }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(7)
    end
  end
end
