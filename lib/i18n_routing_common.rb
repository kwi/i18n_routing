# encoding: utf-8

# I18nRouting module for common usage methods
module I18nRouting
  def self.locale_escaped(locale)
    locale.to_s.downcase.gsub('-', '_')
  end
  
  # Return the correct translation for given values
  def self.translation_for(name, type = :resources, option = nil)
    # First, if an option is given, try to get the translation in the routes scope
    if option
      default = "{option}Noi18nRoutingTranslation"
      t = I18n.t(option, :scope => "routes.#{name}.#{type}", :default => default)
      return (t == default ? nil : t)
    else
      default = "{name}Noi18nRoutingTranslation"

      # Try to get the translation in routes namescope first      
      t = I18n.t(:as, :scope => "routes.#{name}", :default => default)

      return t if t and t != default

      t = I18n.t(name.to_s, :scope => type, :default => default)
      return (t == default ? nil : t)
    end
  end

  DefaultPathNames = [:new, :edit]
  PathNamesKeys = [:path_names, :member, :collection]

  # Return path names hash for given resource
  def self.path_names(name, options)
    h = (options[:path_names] || {}).dup
    
    path_names = DefaultPathNames
    PathNamesKeys.each do |v|
      path_names += options[v].keys if options[v] and Hash === options[v]
    end
    
    path_names.each do |pn|
      n = translation_for(name, :path_names, pn)
      n = nil if n == pn.to_s
      # Get default path_names in path_names scope if no path_names found
      n ||= I18n.t(pn, :scope => :path_names, :default => name.to_s)

      h[pn] = n if n and n != name.to_s
    end

    return h
  end
end
