Gem::Specification.new do |s|
  s.name = "i18n_routing"
  s.version = "0.5.0"
  s.author = "Guillaume Luccisano"
  s.email = "guillaume.luccisano@gmail.com"
  s.homepage = "http://github.com/kwi/i18n_routing"
  s.summary = "I18n routing module for Rails 2.3.x and Rails 3. Translate your routes with ease !"
  s.description = "I18n_routing is a plugin for Ruby on Rails that lets you easily translate your routes trough the I18n api included in Rails since version 2.2"

  s.add_dependency('i18n', '> 0.3.5')

  s.files = Dir["{lib,spec}/**/*", "[A-Z]*", "init.rb"]
  s.require_path = "lib"

  s.rubyforge_project = s.name
  s.required_rubygems_version = ">= 1.3.4"
end