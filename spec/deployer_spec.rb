require 'spec_helper'

RSpec.describe Nomade::Deployer do
  context "linger" do
    it "should accept no linger" do
      expect {
        Nomade::Deployer.new(nomad_endpoint)
      }.not_to raise_error
    end

    it "should accept a linger" do
      expect {
        Nomade::Deployer.new(nomad_endpoint, linger: 10..120)
      }.not_to raise_error
    end

    it "should only accept ranges for linger" do
      expect {
        Nomade::Deployer.new(nomad_endpoint, linger: 10)
      }.to raise_error(Nomade::GeneralError, "Linger needs to be a range, supplied with: Integer")

      expect {
        Nomade::Deployer.new(nomad_endpoint, linger: "10")
      }.to raise_error(Nomade::GeneralError, "Linger needs to be a range, supplied with: String")
    end
  end
end
