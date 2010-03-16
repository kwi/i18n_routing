# encoding: utf8

#
# WARNING : Old and dirty Rails 2.x code
# Need clean up and intensive refactoring
# If you can, use the Rails 3 code wich is really cleaner !
#

module ActionController
  module Routing
    class Route #:nodoc:
      
      alias_method :mkd_initialize, :initialize
      def initialize(segments = [], requirements = {}, conditions = {})
        @glang = requirements.delete(:glang)
        @gnlang = requirements.delete(:gnot_lang)
        mkd_initialize(segments, requirements, conditions)
      end

      private
        def generation_requirements
          requirement_conditions = requirements.collect do |key, req|
            if req.is_a? Regexp
              value_regexp = Regexp.new "\\A#{req.to_s}\\Z"
              "hash[:#{key}] && #{value_regexp.inspect} =~ options[:#{key}]"
            else
              "hash[:#{key}] == #{req.inspect}"
            end
          end
          if !requirement_conditions.empty?
            r = requirement_conditions * ' && '
            if @gnlang
              @gnlang.each do |l|
                r << " && I18n.locale != :#{l}"
              end
            elsif @glang
              r << " && I18n.locale == :#{@glang}"
            end
            return r
          else
            nil
          end
          
        end
    end
  end
end

module ActionController
  module Routing
    class RouteSet #:nodoc: 
      class NamedRouteCollection #:nodoc:

        alias_method :mkd_define_url_helper, :define_url_helper
        def define_url_helper(route, name, kind, options)

          gl = Thread.current[:globalized]
          gls = Thread.current[:globalized_s]

          mkd_define_url_helper(route, name, kind, options)

          # globalization surcouche
          if gl
            selector = url_helper_name(name, kind)
            
            rlang = if i = name.to_s.rindex("_#{gl}")
              "#{selector.to_s[0, i]}_glang_#{gl}#{selector.to_s[i + "_#{gl}".size, selector.to_s.size]}"
            elsif gls and i = name.to_s.rindex("_#{gls}")
              "#{selector.to_s[0, i]}_glang_#{gls}#{selector.to_s[i + "_#{gls}".size, selector.to_s.size]}"
            else
              "glang_#{selector}"
            end

            # surcharge de l'helper
            @module.module_eval <<-end_eval # We use module_eval to avoid leaks
              alias_method :gl#{selector}, :#{selector}

              def #{selector}(*args)
                selector_g = '#{rlang}'.gsub('glang', lang).to_sym

                #logger.debug "Call routes : #{selector} => \#{selector_g} (#{rlang}) "
                if respond_to? selector_g and selector_g != :#{selector}
                  send(selector_g, *args)
                else
                  gl#{selector}(*args)
                end
              end
              protected :gl#{selector}
            end_eval

          end
        end
      end

      alias_method :gl_add_named_route, :add_named_route
      def add_named_route(name, path, options = {}) #:nodoc:
        if options[:globalized] and !path.blank? and !options[:gnot_lang]

          options.delete(:globalized)

          # On check quelle route on peut generer
          name = name.to_s
          langs = []
          I18n.available_locales.each do |l|
            I18n.locale = l
            nt = "#{l}_#{name}"
            if nt != name
              langs << l.to_s
            end
          end

          # Cree la vrai route
          if langs.size > 0
            options.merge!(:gnot_lang => langs)
            Thread.current[:globalized] = name
          end
          

          ### Attention: ici on repasse par le named_route du dessus
          gl_add_named_route(name, path, options)
          
          Thread.current[:globalized] = nil

          options.delete(:gnot_lang)
          langs.each do |l|
            I18n.locale = l
            nt = "#{l}_#{name}"
            troute = I18n.t path.to_s, :scope => :named_routes_path, :default => path.to_s
            gl_add_named_route(nt, troute, options.merge(:glang => l))
          end

        else
          options.delete(:globalized)
          gl_add_named_route(name, path, options)
        end

      end

    end
  end
end

module ActionController
  module Resources
    def create_globalized_resources(type, namespace, *entities, &block)
      opts = entities.dup.extract_options!

      if opts[:globalized]
        name = entities.dup.shift.to_s
  
        opts[:controller] = name if !opts[:controller]
  
        langs = []
        I18n.available_locales.each do |l|
          I18n.locale = l
          nt = "#{l}_#{name}"
          if nt != name and name.t(nil, nil, namespace) != name
            langs << l.to_s
          end
        end

        opts = entities.extract_options!
        if langs.size > 0
          opts[:gnot_lang] = langs
        end

        send(type, *(entities << opts), &block)

        opts.delete(:globalized)
        opts.delete(:gnot_lang)

        # Genere les routes traduites now
        langs.each do |l|
          I18n.locale = l
          nt = "#{l}_#{name}"
          opts[:as] = I18n.t(name, :scope => namespace, :default => name)
          opts[:glang] = l
          send(type, nt.to_sym, opts, &block)
        end

      else
        send(type, *entities, &block)        
      end
    end

    alias_method :gl_resources, :resources
    def resources(*entities, &block)
      create_globalized_resources(:gl_resources, :resources, *entities, &block)
    end

    alias_method :gl_resource, :resource
    def resource(*entities, &block)
      create_globalized_resources(:gl_resource, :resource, *entities, &block)
    end

    private
      def action_options_for(action, resource, method = nil, resource_options = {})
        default_options = { :action => action.to_s }
        require_id = !resource.kind_of?(SingletonResource)
        force_id = resource_options[:force_id] && !resource.kind_of?(SingletonResource)

        opts = case default_options[:action]
          when "index", "new"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements)
          when "create";       default_options.merge(add_conditions_for(resource.conditions, method || :post)).merge(resource.requirements)
          when "show", "edit"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements(require_id))
          when "update";       default_options.merge(add_conditions_for(resource.conditions, method || :put)).merge(resource.requirements(require_id))
          when "destroy";      default_options.merge(add_conditions_for(resource.conditions, method || :delete)).merge(resource.requirements(require_id))
          else                 default_options.merge(add_conditions_for(resource.conditions, method)).merge(resource.requirements(force_id))
        end

        if resource.options[:globalized]
          Thread.current[:globalized] = resource.plural
          if resource.uncountable?
            Thread.current[:globalized] = resource.plural.to_s + '_index'
          end
          Thread.current[:globalized_s] = resource.singular
        else
          Thread.current[:globalized] = nil
          Thread.current[:globalized_s] = nil
        end
        if resource.options[:gnot_lang]
          opts[:gnot_lang] = resource.options[:gnot_lang]
        elsif resource.options[:glang]
          opts[:glang] = resource.options[:glang]
        end

        opts
      end
  end
end