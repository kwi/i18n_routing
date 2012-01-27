require "rubygems"
require "bundler/setup"
require 'rspec'

$rails_version = ARGV.find { |e| e =~ /rails_spec_version=.*/ }.split('=').last.to_i rescue nil

if !$rails_version
  begin
    require 'rails'
  rescue Exception
    $rails_version = 2
  end
end

if !Module.constants.include?('Rails') and $rails_version
  module Rails
    def self.version
      $rails_version.to_s
    end
  end
end

if Rails.version < '3'
  gem 'actionpack', '< 2.9.9'
  require 'action_controller'
  require 'action_controller/routing'
else
  gem 'actionpack', '> 2.9'
  require 'action_controller'
  require 'action_dispatch'
  if Rails.version < '3.2'
    require 'rack/mount'
  else
    require 'journey'
  end
  require 'active_support/core_ext/hash/slice.rb'
end

def rails3?
  !(Rails.version < '3')
end

puts "Launching spec for Rails #{Rails.version}"

# Add I18n load_path
I18n.load_path = (I18n.load_path << Dir[File.join(File.dirname(__FILE__), 'locales', '*.yml')]).uniq

require File.dirname(__FILE__) + '/../init.rb'
