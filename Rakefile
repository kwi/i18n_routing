require 'rubygems'
require 'rake'
require 'spec/rake/spectask'

spec_files = Rake::FileList["spec/**/*_spec.rb"]


desc "Run specs for current Rails version"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = spec_files
  t.spec_opts = lambda {
    @rails_spec_version ? ["-c -- rails_spec_version=#{@rails_spec_version}"] : ["-c"]
  }
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