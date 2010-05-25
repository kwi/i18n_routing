# encoding: utf-8

# I18nRouting module for common usage methods
module I18nRouting
  # Return the correct translation for given values
  def self.translation_for(name, type = :resources, option = nil)

    # First, if an option is given, try to get the translation in the routes scope
    if option
      t = I18n.t(option.to_sym, :scope => "routes.#{name}.#{type}".to_sym, :default => option.to_s)

      return (t || name)
    else
      # Try to get the translation in routes namescope first      
      t = I18n.t(:as, :scope => "routes.#{name}".to_sym, :default => name.to_s)
      return t if t and t != name.to_s

      I18n.t(name.to_s, :scope => type, :default => name.to_s)      
    end
  end
  
  DefaultPathNames = [:new, :edit]
  PathNamesKeys = [:path_names, :member, :collection]

  # Return path names hash for given resource
  def self.path_names(name, options)
    #puts caller.join("\n")
    h = (options[:path_names] || {}).dup
    
    path_names = DefaultPathNames
    PathNamesKeys.each do |v|
      path_names += options[v].keys if options[v] and Hash === options[v]
    end
    
    path_names.each do |pn|
      n = translation_for(name, :path_names, pn)
      n = nil if n == pn.to_s
      n ||= I18n.t(pn, :scope => :path_names, :default => name.to_s)

      h[pn] = n if n and n != name.to_s
    end
    
    #puts "Path Names : #{h.inspect} #{I18n.locale} (#{name})"

    return h
  end

end
