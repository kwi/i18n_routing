# encoding: utf8

#
# WARNING : Old and dirty Rails 2.x code
# Need clean up and intensive refactoring
#

module ActionController
  module Routing
    class Route #:nodoc:
      
      alias_method :mkd_initialize, :initialize
      def initialize(segments = [], requirements = {}, conditions = {})
        @glang = requirements.delete(:glang)
        mkd_initialize(segments, requirements, conditions)
      end

      private
        alias_method :mkd_generation_requirements, :generation_requirements
        # Add locale requirements to ensure good route is used when using url_for
        def generation_requirements
          r = mkd_generation_requirements
          if @glang and !r.blank?
            r << " and I18n.locale == :#{@glang}"
          end
          
          return r
        end
    end
  end
end

module ActionController
  module Routing
    class RouteSet #:nodoc:
      
      attr :locales, true
      attr :i18n_verbose, true
      
      class Mapper
        def localized(locales = I18n.available_locales, opts = {})
          old_value = @set.locales
          @set.locales = locales
          @set.i18n_verbose ||= opts.delete(:verbose)
          yield
        ensure
          @set.locales = old_value
        end
        
      end
       
      class NamedRouteCollection #:nodoc:

        alias_method :mkd_define_url_helper, :define_url_helper
        def define_url_helper(route, name, kind, options)
          gl = Thread.current[:globalized]
          gls = Thread.current[:globalized_s]

          mkd_define_url_helper(route, name, kind, options)

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
                selector_g = '#{rlang}'.gsub('glang', I18n.locale.to_s).to_sym

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
        if @locales and !path.blank?

          name = name.to_s
        
          @locales.each do |l|
            I18n.locale = l
            nt = "#{l}_#{name}"
            if nt != name and ((t = I18n.t(path.to_s, :scope => :named_routes_path, :default => path.to_s)) != path)
              gl_add_named_route(nt, t, options.merge(:glang => l))
              puts("[I18n] > localize %-10s: %40s (%s) => %s" % ['route', name, l, t]) if @i18n_verbose
            end
          end
          
          Thread.current[:globalized] = true
          gl_add_named_route(name, path, options)
          Thread.current[:globalized] = nil
          return
        end

        gl_add_named_route(name, path, options)
      end

    end
  end
end

module ActionController
  module Resources
    class Resource
      alias_method :mkd_initialize, :initialize
      def initialize(entities, options)
        @real_path = options.delete(:real_path)
        @real_path = @real_path.to_s.singularize if @real_path
        
        mkd_initialize(entities, options)
      end

      def nesting_name_prefix
        @real_path ? "#{shallow_name_prefix}#{@real_path}_" : "#{shallow_name_prefix}#{singular}_"
      end
      
      def nesting_path_prefix
        @nesting_path_prefix ||= (@real_path ? "#{shallow_path_prefix}/#{path_segment}/:#{@real_path}_id" : "#{shallow_path_prefix}/#{path_segment}/:#{singular}_id")
      end
    end
    
    def create_globalized_resources(type, namespace, *entities, &block)
      if @set.locales
        name = entities.dup.shift.to_s
  
        options = entities.extract_options!
        opts = options.dup
  
        opts[:controller] ||= name
    
        locales = @set.locales
        localized(nil) do
          locales.each do |l|
            I18n.locale = l
            nt = "#{l}_#{name}"
            if nt != name and ((t = I18n.t(name, :scope => namespace, :default => name)) != name)
              nt = "#{l}_#{name}"
              opts[:as] = t
              opts[:glang] = l
              opts[:globalized] = true
              opts[:real_path] = opts[:singular] || name 
              send(type, nt.to_sym, opts, &block)
              puts("[I18n] > localize %-10s: %40s (%s) => %s" % [namespace, nt, l, t]) if @set.i18n_verbose
            end
          end
        end

        Thread.current[:globalized] = true
        send(type, *(entities << options), &block)
        Thread.current[:globalized] = nil
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
      alias_method :gl_action_options_for, :action_options_for
      def action_options_for(action, resource, method = nil, resource_options = {})
        opts = gl_action_options_for(action, resource, method, resource_options)

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
        if resource.options[:glang]
          opts[:glang] = resource.options[:glang]
        end

        opts
      end
  end
end