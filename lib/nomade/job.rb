module Nomade
  class Job
    def initialize(image_full_name, config_hcl, config_json, config_hash)
      @image_full_name = image_full_name
      @config_hcl = config_hcl
      @config_json = config_json
      @config_hash = config_hash
    end

    def configuration(format)
      case format
      when :hcl
        @config_hcl
      when :json
        @config_json
      when :hash
        @config_hash
      else
        @config_hash
      end
    end

    def job_name
      @config_hash["ID"]
    end

    def job_type
      @config_hash["Type"]
    end

    def image_name_and_version
      @image_full_name
    end

    def image_name
      image_name_and_version.split(":").first
    end

    def image_version
      image_name_and_version.split(":").last
    end

  end
end
