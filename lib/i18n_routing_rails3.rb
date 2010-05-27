# encoding: utf-8
require 'rack/mount'
require 'action_dispatch'
require 'active_support/core_ext/module'

module I18nRouting
  module Mapper

    private
    
    # Just create a Mapper:Resource with given parameters
    def resource_from_params(type, *resources)
      res = resources.clone

      options = res.extract_options!
      r = res.first

      type == :resource ? ActionDispatch::Routing::Mapper::SingletonResource.new(r, options.dup) : ActionDispatch::Routing::Mapper::Resource.new(r, options.dup)
    end
    
    # Localize a resources or a resource
    def localized_resources(type = :resources, *resources, &block)
      localizable_route = nil

      if @locales
        res = resources.clone

        options = res.extract_options!
        r = res.first

        resource = type == :resource ? ActionDispatch::Routing::Mapper::SingletonResource.new(r, options.dup) : ActionDispatch::Routing::Mapper::Resource.new(r, options.dup)

        # Check for translated resource
        @locales.each do |locale|
          I18n.locale = locale
          localized_path = I18nRouting.translation_for(resource.name, type)

          # A translated route exists :
          if localized_path and localized_path != resource.name.to_s
            puts("[I18n] > localize %-10s: %40s (%s) => /%s" % [type, resource.name, locale, localized_path]) if @i18n_verbose
            opts = options.dup
            opts[:path] = localized_path.to_sym
            opts[:controller] ||= r

            res = ["#{locale}_#{r}".to_sym, opts]

            constraints = opts[:constraints] ? opts[:constraints].dup : {}
            constraints[:i18n_locale] = locale.to_s

            scope(:constraints => constraints, :path_names => I18nRouting.path_names(resource.name, @scope)) do
              localized_branch(locale) do
                send(type, *res) do
                  # In the resource(s) block, we need to keep and restore some context :

                  old_name = @scope[:i18n_real_resource_name]
                  old = @scope[:scope_level_resource]
                  old_i = @scope[:i18n_scope_level_resource]

                  @scope[:i18n_real_resource_name] = resource.name
                  @scope[:i18n_scope_level_resource] = old
                  @scope[:scope_level_resource] = resource

                  block.call if block

                  @scope[:i18n_scope_level_resource] = nil
                  @scope[:scope_level_resource] = old
                  @scope[:i18n_real_resource_name] = old_name
                end
              end
            end

            localizable_route = resource
          end
        end
      end
      return localizable_route
    end

    # Set if the next route created will be a localized route or not
    # If yes, localizable is a name, or a Mapper::Resource
    # Can take a block, if so, save the current context, set the new
    # Call the block, then restore the old context and return the block return
    def set_localizable_route(localizable)      
      if block_given?
        old = @set.named_routes.localizable
        @set.named_routes.set_localizable_route(localizable)
        r = yield
        @set.named_routes.set_localizable_route(old)
        return r
      else
        @set.named_routes.set_localizable_route(localizable)
      end
    end
    
    def localizable_route
      @set.named_routes.localizable
    end
    
    # Return the aproximate deep in scope level
    def nested_deep
      (@scope and Array === @scope[:blocks] and @scope[:scope_level]) ? @scope[:blocks].size : 0
    end

    public

    # On Routing::Mapper initialization (when doing Application.routes.draw do ...)
    # prepare routing system to be i18n ready
    def initialize(*args)
      super

      # Add i18n as valid conditions for Rack::Mount
      @valid_conditions = @set.instance_eval { @set }.instance_eval { @valid_conditions }
      @valid_conditions << :i18n_locale if !@valid_conditions.include?(:i18n_locale)

      # Extends the current RouteSet in order to define localized helper for named routes
      # When calling define_url_helper, it calls define_localized_url_helper too.
      if !@set.named_routes.respond_to?(:define_localized_url_helper)
        @set.named_routes.class_eval <<-END_EVAL, __FILE__, __LINE__ + 1
          alias_method :localized_define_url_helper, :define_url_helper
          def define_url_helper(route, name, kind, options)
            localized_define_url_helper(route, name, kind, options)
            define_localized_url_helper(route, name, kind, options)
          end
        END_EVAL

        @set.named_routes.extend I18nRouting::NamedRouteCollection
      end
    end

    # Rails 3 routing system
    # Create a block for localized routes, in your routes.rb :
    #
    # localized do
    #   resources :users
    #   match 'about' => 'contents#about', :as => :about
    # end
    #
    def localized(locales = I18n.available_locales, opts = {})
      old_value = @locales
      @locales = locales
      @i18n_verbose ||= opts.delete(:verbose)
      yield
    ensure
      @locales = old_value
    end
    
    # Create a branch for create routes in the specified locale
    def localized_branch(locale)
      set_localizable_route(nil) do
        old = @localized_branch
        @localized_branch = locale
        localized([locale]) do
          yield
        end
        @localized_branch = old
      end
    end
    
    # Set we do not want to localize next resource
    def skip_localization
      old = @skip_localization
      @skip_localization = @localized_branch ? nil : true
      yield
      @skip_localization = old
    end
    
    def match(*args)
      # Localize simple match only if there is no resource scope.
      if args.size == 1 and @locales and !parent_resource and args.first[:as]
        @locales.each do |locale|
          mapping = LocalizedMapping.new(locale, @set, @scope, Marshal.load(Marshal.dump(args))) # Dump is dirty but how to make deep cloning easily ? :/
          if mapping.localizable?
            puts("[I18n] > localize %-10s: %40s (%s) => %s" % ['route', args.first[:as], locale, mapping.path]) if @i18n_verbose
            @set.add_route(*mapping.to_route)
          end
        end

        # Now, create the real match :
        return set_localizable_route(args.first[:as]) do
          super
        end
      end

      super
    end
    
    def create_globalized_resources(type, *resources, &block)

      #puts "#{' ' * nested_deep}Call #{type} : #{resources.inspect} (#{@locales.inspect}) (#{@localized_branch}) (#{@skip_localization})"

      cur_scope = nil
      if @locales
        localized = localized_resources(type, *resources, &block) if !@skip_localization

        ## We do not translate if we are in a translations branch :
        return if localized and nested_deep > 0

        # Set the current standard resource in order to customize url helper :
        if !@localized_branch
          r = resource_from_params(type, *resources)
          cur_scope = (parent_resource and parent_resource.name == r.name) ? parent_resource : r
        end
      end

      set_localizable_route(cur_scope) do
        skip_localization do
          #puts "#{' ' * nested_deep} \\- Call original #{type} : for #{resources.inspect}}"
          send("#{type}_without_i18n_routing".to_sym, *resources, &block)
        end
      end

    end
    
    # Alias methods in order to handle i18n routes
    def self.included(mod)
      mod.send :alias_method_chain, :resource, :i18n_routing
      mod.send :alias_method_chain, :resources, :i18n_routing
      
      # Here we redefine some methods, in order to handle
      # correct path_names translation on the fly
      [:map_method, :member, :collection].each do |m|
        rfname = "#{m}_without_i18n_routing".to_sym
        mod.send :define_method, "#{m}_with_i18n_routing".to_sym do |*args, &block|
          
           if @localized_branch and @scope[:i18n_scope_level_resource] and @scope[:i18n_real_resource_name]
            o = @scope[:scope_level_resource]
            @scope[:scope_level_resource] = @scope[:i18n_scope_level_resource]

            pname = @scope[:path_names] || {}
            pname[args[1]] = args[1]
            scope(:path_names => I18nRouting.path_names(@scope[:i18n_real_resource_name], {:path_names => pname})) do
              send(rfname, *args, &block)
            end
            @scope[:scope_level_resource] = o
            return
          end

          send(rfname, *args, &block)
          
        end

        mod.send :alias_method_chain, m, :i18n_routing
      end
    end
    
    def resource_with_i18n_routing(*resources, &block)
      create_globalized_resources(:resource, *resources, &block)
    end
    
    def resources_with_i18n_routing(*resources, &block)
      create_globalized_resources(:resources, *resources, &block)
    end

  end

  # Used for localize simple named routes
  class LocalizedMapping < ActionDispatch::Routing::Mapper::Mapping

    attr_reader :path

    def initialize(locale, set, scope, args)
      super(set, scope, args.clone)

      # try to get translated path :
      I18n.locale = locale
      ts = @path.gsub(/^\//, '')
      @localized_path = '/' + I18nRouting.translation_for(ts, :named_routes_path)

      # If a translated path exists, set localized infos
      if @localized_path and @localized_path != @path
        #@options[:controller] ||= @options[:as]
        @options[:as] = "#{locale}_#{@options[:as]}".to_sym
        @path = @localized_path
        @options[:constraints] = @options[:constraints] ? @options[:constraints].dup : {}
        @options[:constraints][:i18n_locale] = locale.to_s
        @options[:anchor] = true
      else
        @localized_path = nil
      end

    end

    # Return true if this route is localizable
    def localizable?
      @localized_path != nil
    end

  end

  module NamedRouteCollection

    attr_reader :localizable

    def set_localizable_route(localizable)
      @localizable = localizable
    end

    # Alias named route helper in order to check if a localized helper exists
    # If not use the standard one.
    def define_localized_url_helper(route, name, kind, options)
      if n = localizable
        selector = url_helper_name(name, kind)

        rlang = if n.kind_of?(ActionDispatch::Routing::Mapper::Resources::Resource) and i = name.to_s.rindex("_#{n.plural}")
                  "#{selector.to_s[0, i]}_glang_#{n.plural}#{selector.to_s[i + "_#{n.plural}".size, selector.to_s.size]}"
                elsif n.kind_of?(ActionDispatch::Routing::Mapper::Resources::Resource) and i = name.to_s.rindex("_#{n.singular}")
                  "#{selector.to_s[0, i]}_glang_#{n.singular}#{selector.to_s[i + "_#{n.singular}".size, selector.to_s.size]}"
                else
                  "glang_#{selector}"
                end

        @module.module_eval <<-end_eval # We use module_eval to avoid leaks
          alias_method :localized_#{selector}, :#{selector}

          def #{selector}(*args)
            selector_g = '#{rlang}'.gsub('glang', I18n.locale.to_s).to_sym

            #puts "Call routes : #{selector} => \#{selector_g} (\#{I18n.locale}) "
            if respond_to? selector_g and selector_g != :#{selector}
              send(selector_g, *args)
            else
              localized_#{selector}(*args)
            end
          end

        end_eval

      end
    end
  end

  # Rack::Mount::Route module
  # Exists in order to use apropriate localized route when using url_for
  module RackMountRoute
    
    # Alias methods in order to handle i18n routes
    def self.included(mod)
      mod.send :alias_method_chain, :generate, :i18n_routing
      mod.send :alias_method_chain, :initialize, :i18n_routing
    end

    # During route initialization, if a condition i18n_locale is present
    # Delete it, and store it in @locale
    def initialize_with_i18n_routing(app, conditions, defaults, name)
      @locale = conditions[:i18n_locale] ? conditions.delete(:i18n_locale).source.to_sym : nil
      initialize_without_i18n_routing(app, conditions, defaults, name)
    end

    # Called for dynamic route generation
    # If a @locale is present and if this locale is not the current one
    #  => return nil and refuse to generate the route
    def generate_with_i18n_routing(method, params = {}, recall = {}, options = {})
      return nil if @locale and @locale != I18n.locale
      generate_without_i18n_routing(method, params, recall, options)
    end

  end
end

ActionDispatch::Routing::Mapper.send  :include, I18nRouting::Mapper
Rack::Mount::Route.send               :include, I18nRouting::RackMountRoute
