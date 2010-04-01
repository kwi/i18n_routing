require File.dirname(__FILE__) + '/../spec_helper'

describe :non_localized_routes do
  before(:each) do

    ActionController::Routing::Routes.clear!

    if Rails.version < '3'

      ActionController::Routing::Routes.draw do |map|
        map.about 'about', :controller => 'about'

        map.resources :users
        map.resource  :contact
      end

    else

      ActionController::Routing::Routes.draw do
        match 'about' => "about#show", :as => :about

        resources :users
        resource  :contact
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

  it "should still work for non localized named_route" do
    routes.send(:about_path).should == "/about"
  end
  
  it "should still work for non localized resource" do
    routes.send(:contact_path).should == "/contact"
  end
  
  it "should still work for non localized resources" do
    routes.send(:users_path).should == "/users"
  end

end