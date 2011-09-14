require 'spec_helper'

describe :localized_routes do

  $r = nil # Global routes in order to speed up testing
  
  before(:all) do

    if !$r
      if !rails3?
        ActionController::Routing::Routes.clear!
        ActionController::Routing::Routes.draw do |map|
          map.not_about 'not_about', :controller => 'not_about'
          map.resources :not_users
          map.resource  :not_contact

          map.localized(I18n.available_locales, :verbose => false) do
            map.about 'about', :controller => 'about', :action => :show
            map.welcome 'welcome/to/our/page', :controller => :welcome, :action => :index
            map.empty 'empty', :controller => 'empty', :action => :show
            
            map.resources :users, :member => {:level => :get, :one => :get, :two => :get}, :collection => {:groups => :get}
            map.resource  :contact
            
            map.resources :authors do |m|
              m.resources :books
            end
            
            map.resources :empty_resources
            
            map.resource :foo do |m|
              m.resources :bars
              m.resource :foofoo do |mm|
                mm.resources :bars
              end
            end
            
            map.resources :universes do |m|
              m.resources :galaxies do |mm|
                mm.resources :planets do |mmm|
                  mmm.resources :countries
                end
              end
            end
            
            map.with_options :path_prefix => ':locale' do |l|
              l.localized_root '/', :controller => "about", :action => "show"
              l.about_with_locale 'about', :controller => "about", :action => "show"
              l.about_with_locale_with_sep 'about', :controller => "about", :action => "show"
              l.resources :empty__resources
            end
            
            map.resources :drones, :path_prefix => 'doubledrones/unimatrix/zero'
          end
        end
      
        $r = ActionController::Routing::Routes
      
        class UrlTester
          include ActionController::UrlWriter
        end

      else

        $r = ActionDispatch::Routing::RouteSet.new
        $r.draw do
          match 'not_about' => "not_about#show", :as => :not_about
          match 'not_about2', :to => "not_about2#show"
          match 'not_home', :to => 'not_pages#home', :as => 'not_main'

          resources :not_users
          resources :empty_resources
          resource  :not_contact

          localized(I18n.available_locales, :verbose => true) do
            match 'about' => "about#show", :as => :about
            match 'about2', :to => "about2#show"
            match 'home', :to => 'pages#home', :as => 'main'


            match 'welcome/to/our/page' => "welcome#index", :as => :welcome
            match 'empty' => 'empty#show', :as => :empty

            scope '/:locale', :constraints => { :locale => /[a-z]{2}/ } do ### this constraint fail on rails 3.0.4, so I had to hack a turn around
              match '/' => "about#show", :as => :localized_root
              match 'about' => "about#show", :as => :about_with_locale
              match '/about' => "about#show", :as => :about_with_locale_with_sep
              resources :empty__resources
            end

            resources :users do
              member do
                get :level
                get :one, :two
              end
              get :groups, :on => :collection
            end
            resource  :contact

            resources :authors do
              resources :books
            end

            resource :foo do
              resources :bars
              resource :foofoo do
                resources :bars
              end
            end

            scope "german" do
              match "/sausage" => "meal#show", :as => :german_sausage
              resources :weshs do
                resources :in_weshs
              end
            end

            resources :universes do
              resources :galaxies do
                resources :planets do
                  scope do
                    resources :countries
                  end
                end
              end
            end

          end
        end
           
        class UrlTester; end
        UrlTester.send :include, $r.url_helpers

      end
    end

  end

  let(:nested_routes) { $r.named_routes.instance_eval { routes } }
  let(:routes) { UrlTester.new }

  def url_for(opts)
    $r.generate_extras(opts).first
  end

  context "do not break existing behavior" do

    it "of named_routes" do
      routes.send(:not_about_path).should == "/not_about"
    end

    if rails3?
      it "of named_routes (another format)" do
        routes.send(:not_about2_path).should == "/not_about2"
      end
    end

    it "of a singular resource" do
      routes.send(:not_contact_path).should == "/not_contact"
    end

    it "of resources" do
      routes.send(:not_users_path).should == "/not_users"
    end

  end

  context "for default routes" do

    before do
      I18n.locale = :de # Not localized
    end

    it "named_route uses default values" do
      routes.send(:about_path).should == "/about"
      if rails3?
        routes.send(:about2_path).should == "/about2"
        routes.send(:main_path).should == "/home"
      end
      routes.send(:welcome_path).should == '/welcome/to/our/page'
    end

    it "resource generates routes using default values" do
      routes.send(:contact_path).should == "/contact"
    end

    it "resources generates routes using default values" do
      routes.send(:users_path).should == "/users"
    end

    it "url_for generates route using default values" do
      url_for(:controller => :users).should == "/users"
    end

    it "nested resources generate routes using default values" do
      routes.send(:author_books_path, 1).should == "/authors/1/books"
    end

    it "deep nested resources generate routes using default values" do
      routes.send(:universes_path).should == "/universes"
      routes.send(:universe_galaxies_path, 1).should == "/universes/1/galaxies"
      routes.send(:universe_galaxy_planets_path, 1, 1).should == "/universes/1/galaxies/1/planets"
    end
    
    it "single resource should have by default the pluralized controller" do
      nested_routes[:foo].defaults[:controller].should == 'foos'
    end
    
    it "scope with parameters should be respected" do
      routes.send(:localized_root_path, I18n.locale).should == "/#{I18n.locale}"
    end

    it "scope with parameters should be respected when filled" do
      routes.send(:about_with_locale_path, I18n.locale).should == "/#{I18n.locale}/about"
      routes.send(:about_with_locale_with_sep_path, I18n.locale).should == "/#{I18n.locale}/about"
    end

  end

  context "" do

    before do
      I18n.locale = :fr
    end
    
    it "scope with parameters should be respected" do
      routes.send(:localized_root_path, I18n.locale).should == "/#{I18n.locale}"
    end

    it "scope with parameters should be respected when filled" do
      routes.send(:about_with_locale_path, I18n.locale).should == "/#{I18n.locale}/#{I18n.t :about, :scope => :named_routes_path}"
      routes.send(:about_with_locale_with_sep_path, I18n.locale).should == "/#{I18n.locale}/#{I18n.t :about, :scope => :named_routes_path}"
    end

    it "named_route generates route using localized values" do
      routes.send(:about_path).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      if rails3?
        routes.send(:about2_path).should == "/#{I18n.t :about2, :scope => :named_routes_path}"
        routes.send(:main_path).should == "/#{I18n.t :home, :scope => :named_routes_path}"
      end
    end


    it "named_route generated route from actual route name" do
      I18n.locale = :en
      routes.send(:welcome_path).should == "/#{I18n.t :welcome, :scope => :named_routes}"        
      I18n.locale = :fr
    end
    
    it "named_route generates route from route path when route name  not available" do
      routes.send(:welcome_path).should == "/#{I18n.t 'welcome/to/our/page', :scope => :named_routes_path}"
    end 
    
    it "doesn't translate empty route" do
      routes.send(:empty_path).should_not == "/#{I18n.t 'empty', :scope => :named_routes_path}"
      routes.send(:empty_path).should == "/empty"
      routes.send(:empty_resources_path).should_not == "/#{I18n.t 'empty', :scope => :named_routes_path}"
      routes.send(:empty_resources_path).should == "/empty_resources"
      nested_routes.keys.include?(:fr_empty__resources).should == false # Because translation is empty
      nested_routes.keys.include?('fr_empty__resources').should == false # Because translation is empty
    end

    it "named_route generates route using localized values and I18n.locale as a string" do
      o = I18n.locale
      I18n.locale = "fr"
      routes.send(:about_path).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      if rails3?
        routes.send(:about2_path).should == "/#{I18n.t :about2, :scope => :named_routes_path}"
        routes.send(:main_path).should == "/#{I18n.t :home, :scope => :named_routes_path}"
      end
      I18n.locale = o
    end


    it "resource generates routes using localized values" do
      routes.send(:contact_path).should == "/#{I18n.t :contact, :scope => :resource}"
    end

    it "resources generates routes using localized values" do
      routes.send(:users_path).should == "/#{I18n.t :as, :scope => :'routes.users'}"
    end

    it "url_for generates routes using localized values" do
      url_for(:controller => :users).should == "/#{I18n.t :as, :scope => :'routes.users'}"
      url_for(:controller => :about, :action => :show).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      if rails3?
        url_for(:controller => :about2, :action => :show).should == "/#{I18n.t :about2, :scope => :named_routes_path}"
        url_for(:controller => :pages, :action => :home).should == "/#{I18n.t :home, :scope => :named_routes_path}"
      end
    end

    if !rails3?
      it "url_for generates routes for drones with path prefix" do
        url_for(:controller => :drones).should == "#{I18n.t :path_prefix, :scope => :'routes.drones'}/#{I18n.t :as, :scope => :'routes.drones'}"
      end
    end

    it "nested resources generate routes using localized values" do
      routes.send(:author_books_path, 1).should == "/#{I18n.t :authors, :scope => :resources}/1/#{I18n.t :books, :scope => :resources}"
    end

    it "deep nested resources generate routes using localized values and translate routes even translated name is the same" do
      routes.send(:universes_path).should == "/#{I18n.t :universes, :scope => :resources}"
      routes.send(:universe_galaxies_path, 1).should == "/#{I18n.t :universes, :scope => :resources}/1/#{I18n.t :galaxies, :scope => :resources}"
      routes.send(:universe_galaxy_planets_path, 1, 1).should == "/#{I18n.t :universes, :scope => :resources}/1/#{I18n.t :galaxies, :scope => :resources}/1/#{I18n.t :planets, :scope => :resources}"
      routes.send(:universe_galaxy_planet_countries_path, 1, 1, 42).should == "/#{I18n.t :universes, :scope => :resources}/1/#{I18n.t :galaxies, :scope => :resources}/1/#{I18n.t :planets, :scope => :resources}/42/#{I18n.t :countries, :scope => :resources}"
    end

    context "with path_names" do
      
      it "default translated path names" do
        routes.send(:new_universe_path).should == "/#{I18n.t :universes, :scope => :resources}/#{I18n.t :new, :scope => :path_names}"
        routes.send(:edit_universe_path, 42).should == "/#{I18n.t :universes, :scope => :resources}/42/#{I18n.t :edit, :scope => :path_names}"
      end
      
      it "custom translated path names" do
        routes.send(:new_user_path).should == "/#{I18n.t :users, :scope => :resources}/#{I18n.t :new, :scope => :'routes.users.path_names'}"
        routes.send(:edit_user_path, 42).should == "/#{I18n.t :users, :scope => :resources}/42/#{I18n.t :edit, :scope => :'routes.users.path_names'}"
      end
      
    end
    
    context "with member and collection" do

      it "custom member" do
        I18n.locale = :en
        routes.send(:level_user_path, 42).should == "/#{I18n.t :users, :scope => :resources}/42/level"        
        I18n.locale = :fr
        routes.send(:level_user_path, 42).should == "/#{I18n.t :users, :scope => :resources}/42/#{I18n.t :level, :scope => :'routes.users.path_names'}"
        routes.send(:one_user_path, 42).should == "/#{I18n.t :users, :scope => :resources}/42/#{I18n.t :one, :scope => :'routes.users.path_names'}"
        routes.send(:two_user_path, 42).should == "/#{I18n.t :users, :scope => :resources}/42/#{I18n.t :two, :scope => :'routes.users.path_names'}"
      end

      it "custom collection" do
        I18n.locale = :en
        routes.send(:groups_users_path).should == "/#{I18n.t :users, :scope => :resources}/groups"        
        I18n.locale = :fr
        routes.send(:groups_users_path).should == "/#{I18n.t :users, :scope => :resources}/#{I18n.t :groups, :scope => :'routes.users.path_names'}"
      end

    end

    context "when nested" do

      it "named routes should not be nil" do
        nested_routes[:author_fr_books].should_not be_nil
      end

      context "in Rails #{Rails.version}" do
        it "include the correct significant keys" do
          v = !rails3? ? :significant_keys : :segment_keys
          nested_routes[:author_books].send(v).should include(:author_id)
          nested_routes[:author_fr_books].send(v).should include(:author_id)
        end
      end

    end

    context "when nested inside a singleton resource" do

      it "named routes should have locale placed at correct position" do
        nested_routes[:fr_foo_fr_bars].should be_nil
        nested_routes[:foo_fr_bars].should_not be_nil
      end

      it "routes for the singleton resource alone should be translated correctly" do
        routes.send(:foo_path).should == "/#{I18n.t :foo, :scope => :resource}"
      end

      it "routes should be translated correctly" do
        routes.send(:foo_bars_path).should == "/#{I18n.t :foo, :scope => :resource}/#{I18n.t :bars, :scope => :resources}"
      end

      it "routes should be translated correctly also with deep nested singleton resource" do
        routes.send(:foo_foofoo_bars_path).should == "/#{I18n.t :foo, :scope => :resource}/#{I18n.t :foofoo, :scope => :resource}/#{I18n.t :bars, :scope => :resources}"
      end

    end

    context "when deeply nested" do

      it "named routes should not be nil" do
        nested_routes[:universe_galaxy_fr_planet].should_not be_nil
      end

      context "in Rails #{Rails.version}" do
        it "include the correct significant keys" do
          v = !rails3? ? :significant_keys : :segment_keys
          nested_routes[:universe_galaxy_planet].send(v).should include(:universe_id)
          nested_routes[:universe_galaxy_fr_planet].send(v).should include(:universe_id)
          nested_routes[:universe_galaxy_planet].send(v).should include(:galaxy_id)
          nested_routes[:universe_galaxy_fr_planet].send(v).should include(:galaxy_id)
        end
      end
    end

    it "nested resources do not deep translate with multi helpers" do
      nested_routes.keys.should_not include(:fr_author_books) # Do not want fr_author_books
    end    

  end

  if rails3?
    context 'routes with scope' do

      before do
        I18n.locale = 'de'
      end

      it "should translate the scope too" do
        routes.send(:german_sausage_path).should == "/#{I18n.t :german, :scope => :scopes}/#{I18n.t :sausage, :scope => :named_routes_path}"
        # Scoping is not yet supported on resources ...
        #routes.send(:weshs_path).should == "/#{I18n.t :german, :scope => :scopes}/weshs"
      end

      it "should translate the scope too and even in french!" do
        I18n.locale = 'fr'
        routes.send(:german_sausage_path).should == "/#{I18n.t :german, :scope => :scopes}/#{I18n.t :sausage, :scope => :named_routes_path}"
        # Scoping is not yet supported on resources ...
        #routes.send(:weshs_path).should == "/#{I18n.t :german, :scope => :scopes}/#{I18n.t :weshs, :scope => :resources}"
        #routes.send(:wesh_in_wesh_path).should == "/#{I18n.t :german, :scope => :scopes}/#{I18n.t :weshs, :scope => :resources}/#{I18n.t :in_weshs, :scope => :resources}"
      end
    
    end
  end

  context 'locale with a dash (pt-br)' do

    before do
      I18n.locale = 'pt-BR'
    end

    it 'users resources' do
      routes.send(:users_path).should == "/#{I18n.t :users, :scope => :'resources'}"
    end
    
    it "routes for the singleton resource alone should be translated correctly" do
      routes.send(:foo_path).should == "/#{I18n.t :foo, :scope => :resource}"
    end
    
    it "named_route generates route using localized values" do
      routes.send(:about_path).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      if rails3?
        routes.send(:about2_path).should == "/#{I18n.t :about2, :scope => :named_routes_path}"
        routes.send(:main_path).should == "/#{I18n.t :home, :scope => :named_routes_path}"
      end
    end
    
    it "custom translated path names" do
      routes.send(:new_user_path).should == "/#{I18n.t :users, :scope => :resources}/#{I18n.t :new, :scope => :'path_names'}"
    end
    
  end

  # context "just output" do
  #   it "output all routes properly" do
  #     nested_routes.keys.collect(&:to_s).sort.each do |k|
  #       puts("%50s: %.80s" % [k, (nested_routes[k.to_sym].path rescue nested_routes[k.to_sym].to_s)])
  #     end
  #   end
  # end

end
