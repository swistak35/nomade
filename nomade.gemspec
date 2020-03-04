Gem::Specification.new do |s|
  s.name = "nomade"
  s.author = "Kasper Grubbe"
  s.email = "nomade@kaspergrubbe.com"
  s.license = "MIT"
  s.homepage = "https://billetto.com"
  s.version = "0.1.1"
  s.summary = "Gem that deploys nomad jobs"
  s.files = [
    "lib/nomade.rb",
    "lib/nomade/decorators.rb",
    "lib/nomade/deployer.rb",
    "lib/nomade/exceptions.rb",
    "lib/nomade/hooks.rb",
    "lib/nomade/http.rb",
    "lib/nomade/job.rb",
    "lib/nomade/job_builder.rb",
    "lib/nomade/logger.rb",
  ]
  s.require_paths = ["lib"]
  s.add_runtime_dependency "yell", "~> 2.2.0"
  s.add_development_dependency "pry", "~> 0.12.2"
  s.add_development_dependency "rspec", "~> 3.9.0"
  s.add_development_dependency "simplecov", "~> 0.18.5"
  s.add_development_dependency "irb", "~> 1.0.0"
end
