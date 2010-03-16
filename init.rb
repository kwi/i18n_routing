# encoding: utf-8
if Rails.version < '3'
  require File.join(File.dirname(__FILE__), 'lib', 'i18n_routing_rails2', '*.rb')
else
  require File.join(File.dirname(__FILE__), 'lib', 'i18n_routing_rails3', '*.rb')
end