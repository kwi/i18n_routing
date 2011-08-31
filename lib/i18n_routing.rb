# encoding: utf-8
require 'i18n_routing_common'

if Rails.version < '3'
  require 'i18n_routing_rails2'
else
  require 'i18n_routing_rails3'
end
