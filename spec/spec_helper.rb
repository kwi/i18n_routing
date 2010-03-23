require 'rubygems'
require 'spec'

$rails_version = nil

ARGV.each do |e|
  if e =~ /rails_spec_version=.*/
    $rails_version = e.split('=').last.to_i
  end
end

require 'rails' if !$rails_version

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
  require 'rack/mount'
end

puts "Launching spec for Rails #{Rails.version}"

# Add I18n load_path
I18n.load_path = (I18n.load_path << Dir[File.join(File.dirname(__FILE__), 'locales', '*.yml')]).uniq

module I18nRouting
end

require File.dirname(__FILE__) + '/../init.rb'

