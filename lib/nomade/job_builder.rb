require "erb"
require "json"

module Nomade
  class JobBuilder
    def initialize(http)
      @http = http
    end

    def build(template_file, image_full_name, template_variables = {})
      # image_full_name should be in the form of:
      # redis:4.0.1
      # kaspergrubbe/secretimage:latest
      # billetto/billetto-rails:4.2.24
      unless image_full_name.match(/\A[a-zA-Z0-9\/\-\_]+\:[a-zA-Z0-9\.\-\_]+\z/)
        raise Nomade::FormattingError.new("Image-format wrong: #{image_full_name}")
      end

      job_hcl = render_erb(template_file, image_full_name, template_variables)
      job_json = @http.convert_hcl_to_json(job_hcl)
      job_hash = JSON.parse(job_json)

      Nomade::Job.new(image_full_name, job_hcl, job_json, job_hash)
    end

    private

    def render_erb(erb_template, image_full_name, template_variables)
      file = File.open(erb_template).read

      local_binding = binding
      local_binding.local_variable_set(:image_name_and_version, image_full_name)
      local_binding.local_variable_set(:image_full_name, image_full_name)
      local_binding.local_variable_set(:template_variables, template_variables)
      rendered = ERB.new(file, nil, '-').result(local_binding)

      rendered
    end
  end
end
