# encoding: utf-8
require 'rack/mount'
require 'action_dispatch'

module I18nRouting
  module Mapper

    private
    # Localize a resources or a resource
    def localized_resources(type = :resources, *resources, &block)
      localizable_route = nil

      if @locales
        res = resources.clone

        options = res.extract_options!
        r = res.first
        resource = type == :resource ? ActionDispatch::Routing::Mapper::SingletonResource.new(r, options) : ActionDispatch::Routing::Mapper::Resource.new(r, options)

        # Check for translated resource
        @locales.each do |locale|
          I18n.locale = locale
          localized_path = I18n.t(resource.name, :scope => type, :default => resource.name.to_s)

          # A translated route exists :
          if localized_path and localized_path != resource.name.to_s
            puts("[I18n] > localize %-10s: %40s (%s) => %s" % [type, resource.name, locale, localized_path]) if @i18n_verbose
            opts = options.dup
            opts[:path] = localized_path.to_sym
            opts[:controller] ||= r
            opts[:constraints] = opts[:constraints] ? opts[:constraints].dup : {}
            opts[:constraints][:i18n_locale] = locale.to_s
            res = ["#{locale}_#{r}".to_sym, opts]

            # Create the localized resource(s)
            scope(:constraints => opts[:constraints]) do
              localized(nil) do
                send(type, *res, &block)
              end
            end

            localizable_route = resource
          end
        end
      end
      return localizable_route
    end

    # Set if the next route creation will be a localied route or not
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
      @i18n_verbose = opts.delete(:verbose)
      yield
    ensure
      @locales = old_value
    end

    def match(*args)
      # Localize simple match only if there is no resource scope.
      if args.size == 1 and @locales and !@scope[:scope_level_resource] and args.first[:as]
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

    def resource(*resources, &block)
      set_localizable_route(nil) do
        set_localizable_route(localized_resources(:resource, *resources, &block))
        super
      end
    end

    def resources(*resources, &block)
      set_localizable_route(nil) do
        set_localizable_route(localized_resources(:resources, *resources, &block))
        super
      end
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
      @localized_path = '/' + I18n.t(ts, :scope => :named_routes_path, :default => ts)

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

    # During route initialization, if a condition i18n_locale is present
    # Delete it, and store it in @locale
    def initialize(app, conditions, defaults, name)
      @locale = conditions[:i18n_locale] ? conditions.delete(:i18n_locale).source.to_sym : nil
      super
    end

    # Called for dynamic route generation
    # If a @locale is present and if this locale is not the current one
    #  => return nil and refuse to generate the route
    def generate(method, params = {}, recall = {}, options = {})
      return nil if @locale and @locale != I18n.locale
      super
    end

  end
end

ActionDispatch::Routing::Mapper.send  :include, I18nRouting::Mapper
Rack::Mount::Route.send               :include, I18nRouting::RackMountRoute
