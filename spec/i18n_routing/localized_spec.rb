require File.dirname(__FILE__) + '/../spec_helper'

describe I18nRouting do
  before(:each) do
    
    ActionController::Routing::Routes.clear!

    if Rails.version < '3'

      ActionController::Routing::Routes.draw do |map|
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
        localized do
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
    routes.send(:url_for, :controller => :users, :only_path => true).should == "/#{I18n.t :users, :scope => :resources}"
    routes.send(:url_for, :controller => :about, :action => :show, :only_path => true).should == "/#{I18n.t :about, :scope => :named_routes_path}"
    I18n.locale = :en
    routes.send(:url_for, :controller => :users, :only_path => true).should == "/#{I18n.t :users, :scope => :resources}"
    I18n.locale = :de # Not localized
    routes.send(:url_for, :controller => :users, :only_path => true).should == "/users"
  end
  
  # it "should have correct controller requirements" do
  # 
  # end
  
  it "should works with nested resources" do
    I18n.locale = :fr
    routes.send(:authors_path).should == "/#{I18n.t :authors, :scope => :resources}"
    routes.send(:author_books_path, 1).should == "/#{I18n.t :authors, :scope => :resources}/1/#{I18n.t :books, :scope => :resources}"
    I18n.locale = :de # Not localized
    routes.send(:authors_path).should == "/authors"
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
    routes.send(:universe_galaxy_planets_path, 1, 1).should == "/universes/1/galaxy/1/planets"
  end
  
  it "should nested resources have correct significant_keys" do
    r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
    #puts r.keys.to_yaml

    r[:fr_author_books].should_not be_nil
  
    if Rails.version < '3'
      r[:author_books].significant_keys.should include(:author_id)
      r[:fr_author_books].significant_keys.should include(:author_id)
    else
      r[:author_books].segment_keys.should include(:author_id)
      r[:fr_author_books].segment_keys.should include(:author_id)
    end
  end
  
  it "should nested resources not deep translate with multi helpers" do
    r = ActionController::Routing::Routes.named_routes.instance_eval { @routes }
  
    r.keys.should_not include(:author_fr_books) # Whant fr_author_books
  end

end