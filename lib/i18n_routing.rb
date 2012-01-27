# encoding: utf-8
require 'i18n_routing_common'

if Rails.version < '3'
  require 'i18n_routing_rails2'
elsif Rails.version >= '3.2'
  require 'i18n_routing_rails32'
else
  require 'i18n_routing_rails31'
end
