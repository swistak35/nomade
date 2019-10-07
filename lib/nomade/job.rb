require "erb"
require "json"

module Nomade
  class Job
    class FormattingError < StandardError; end

    def initialize(template_file, image_full_name, environment_variables = {})
      @image_full_name = image_full_name
      @environment_variables = environment_variables

      # image_full_name should be in the form of:
      # redis:4.0.1
      # kaspergrubbe/secretimage:latest
      unless @image_full_name.match(/\A[a-zA-Z0-9\/]+\:[a-zA-Z0-9\.\-\_]+\z/)
        raise Nomade::Job::FormattingError.new("Image-format wrong: #{@image_full_name}")
      end

      @config_hcl = render_erb(template_file)
      @config_json = convert_job_hcl_to_json(@config_hcl)
      @config_hash = JSON.parse(@config_json)
    end

    def configuration(format)
      case format
      when :hcl
        @config_hcl
      when :json
        @config_json
      else
        @config_hash
      end
    end

    def job_name
      @config_hash["Job"]["ID"]
    end

    def job_type
      @config_hash["Job"]["Type"]
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

    def environment_variables
      @environment_variables
    end

    private

    def render_erb(erb_template)
      file = File.open(erb_template).read
      rendered = ERB.new(file, nil, '-').result(binding)

      rendered
    end

    def convert_job_hcl_to_json(rendered_template)
      exit_status, stdout, stderr = Shell.exec("nomad job run -output -no-color -", rendered_template)

      JSON.pretty_generate({
        "Job": JSON.parse(stdout)["Job"],
      })
    end
  end
end
