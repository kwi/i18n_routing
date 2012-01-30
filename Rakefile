require 'rubygems'
require 'rake'
require 'rspec/core/rake_task'

# Now using RSpec 2

desc "Run specs for current Rails version"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.verbose = true
  # t.ruby_opts = lambda {
  #   @rails_spec_version ? ["-c --format specdoc -- rails_spec_version=#{@rails_spec_version}"] : ["-c --format specdoc"]
  # }
end

task :default => :spec

desc "Run Rails 2.x specs"
task :rails2_spec do
  @rails_spec_version = 2
  Rake::Task['spec'].invoke
end

desc "Run Rails 3.x specs"
task :rails3_spec do
  @rails_spec_version = 3
  Rake::Task['spec'].invoke
end

Bundler::GemHelper.install_tasks

