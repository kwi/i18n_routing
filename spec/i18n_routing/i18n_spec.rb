require 'spec_helper'

describe :localized_routes do
  before(:all) do
    
    puts "Route for localize spec"
    ActionController::Routing::Routes.clear!

    if Rails.version < '3'

      ActionController::Routing::Routes.draw do |map|
        map.not_about 'not_about', :controller => 'not_about'
        map.resources :not_users
        map.resource  :not_contact

        map.localized do
          map.about 'about', :controller => 'about', :action => :show

          map.resources :users
          map.resource  :contact

          map.resources :authors do |m|
            m.resources :books
          end

          map.resources :universes do |m|
            m.resources :galaxies do |mm|
              mm.resources :planets
            end
          end
        end
      end

    else

      ActionController::Routing::Routes.draw do
        match 'not_about' => "not_about#show", :as => :not_about
        resources :not_users
        resource  :not_contact

        localized(I18n.available_locales, :verbose => true) do
          match 'about' => "about#show", :as => :about

          resources :users
          resource  :contact
          
          resources :authors do
            resources :books
          end
        
          resources :universes do
            resources :galaxies do
              resources :planets
            end
          end
              
        end
      end
      
    end


    class UrlTester
      include ActionController::UrlWriter
    end

    @routes = UrlTester.new
  end
  
  def routes
    @routes
  end
  
  def url_for(opts)
    ActionController::Routing::Routes.generate_extras(opts).first
  end

  it "should still work for non localized named_route" do
    routes.send(:not_about_path).should == "/not_about"
  end
  
  it "should still work for non localized resource" do
    routes.send(:not_contact_path).should == "/not_contact"
  end
  
  it "should still work for non localized resources" do
    routes.send(:not_users_path).should == "/not_users"
  end

  it "should works for localized named_route" do
      I18n.locale = :fr
      routes.send(:about_path).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      I18n.locale = :en
      routes.send(:about_path).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      I18n.locale = :de # Not localized
      routes.send(:about_path).should == "/about"
    end
    
    it "should works for localized resource" do
      I18n.locale = :fr
      routes.send(:contact_path).should == "/#{I18n.t :contact, :scope => :resource}"
      I18n.locale = :en
      routes.send(:contact_path).should == "/#{I18n.t :contact, :scope => :resource}"
      I18n.locale = :de # Not localized
      routes.send(:contact_path).should == "/contact"
    end
    
    it "should works for localized resources" do
      I18n.locale = :fr
      routes.send(:users_path).should == "/#{I18n.t :users, :scope => :resources}"
      I18n.locale = :en
      routes.send(:users_path).should == "/#{I18n.t :users, :scope => :resources}"
      I18n.locale = :de # Not localized
      routes.send(:users_path).should == "/users"
    end
    
    it "should works with url_for" do
      I18n.locale = :fr
      url_for(:controller => :users).should == "/#{I18n.t :users, :scope => :resources}"
      url_for(:controller => :about, :action => :show).should == "/#{I18n.t :about, :scope => :named_routes_path}"
      I18n.locale = :en
      url_for(:controller => :users).should == "/#{I18n.t :users, :scope => :resources}"
      I18n.locale = :de # Not localized
      url_for(:controller => :users).should == "/users"
    end
    
    it "should have correct controller requirements" do
    
    end
    
    it "should main resources works with nested resources" do
      I18n.locale = :fr
      routes.send(:authors_path).should == "/#{I18n.t :authors, :scope => :resources}"
      I18n.locale = :de # Not localized
      routes.send(:authors_path).should == "/authors"
    end
    
    it "should works with nested resources" do
      I18n.locale = :fr
      routes.send(:author_books_path, 1).should == "/#{I18n.t :authors, :scope => :resources}/1/#{I18n.t :books, :scope => :resources}"
      I18n.locale = :de # Not localized
      routes.send(:author_books_path, 1).should == "/authors/1/books"
    end
    
    it "should works with deep nested resources" do
      I18n.locale = :fr
      routes.send(:universes_path).should == "/#{I18n.t :universes, :scope => :resources}"
      routes.send(:universe_galaxies_path, 1).should == "/#{I18n.t :universes, :scope => :resources}/1/#{I18n.t :galaxies, :scope => :resources}"
      routes.send(:universe_galaxy_planets_path, 1, 1).should == "/#{I18n.t :universes, :scope => :resources}/1/#{I18n.t :galaxies, :scope => :resources}/1/#{I18n.t :planets, :scope => :resources}"
      I18n.locale = :de # Not localized
      routes.send(:universes_path).should == "/universes"
      routes.send(:universe_galaxies_path, 1).should == "/universes/1/galaxies"
      routes.send(:universe_galaxy_planets_path, 1, 1).should == "/universes/1/galaxies/1/planets"
    end
  
    it "should nested resources have correct significant_keys" do
      r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
      #puts r.keys.to_yaml
    
      r[:author_fr_books].should_not be_nil
    
      if Rails.version < '3'
        r[:author_books].significant_keys.should include(:author_id)
        r[:author_fr_books].significant_keys.should include(:author_id)
      else
        r[:author_books].segment_keys.should include(:author_id)
        r[:author_fr_books].segment_keys.should include(:author_id)
      end
    end
    
    it "should deep nested resources have correct significant_keys" do
      r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
      #puts r.keys.to_yaml
    
      r[:universe_galaxy_fr_planet].should_not be_nil
    
      if Rails.version < '3'
        r[:universe_galaxy_planet].significant_keys.should include(:universe_id)
        r[:universe_galaxy_fr_planet].significant_keys.should include(:universe_id)
        r[:universe_galaxy_planet].significant_keys.should include(:galaxy_id)
        r[:universe_galaxy_fr_planet].significant_keys.should include(:galaxy_id)
      else
        r[:universe_galaxy_planet].segment_keys.should include(:universe_id)
        r[:universe_galaxy_fr_planet].segment_keys.should include(:universe_id)
        r[:universe_galaxy_planet].segment_keys.should include(:galaxy_id)
        r[:universe_galaxy_fr_planet].segment_keys.should include(:galaxy_id)
      end
    end

    it "should nested resources not deep translate with multi helpers" do
      r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
    
      r.keys.should_not include(:fr_author_books) # Whant fr_author_books
    end
  
  # it "zZ Just print routes :)" do
  #   r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
  #   puts r.keys.collect(&:to_s).sort.to_yaml
  #   puts "Nb Routes : #{r.keys.size}"
  # end

end