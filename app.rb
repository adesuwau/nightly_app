require 'sinatra/base'
require 'securerandom'
require 'httparty'
require 'redis'
require 'yelp'
require 'twitter'
require 'instagram'
require 'pry'
require 'rss'
require 'open-uri'


class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions
    GITHUB_CLIENT_ID     = "6b7eb4b33d119b28399c"
    GITHUB_CLIENT_SECRET = "4c1a5e68069ccff83c6cf62f7e206fad59009f23"
    GITHUB_CALLBACK_URL  = "http://127.0.0.1:9292/oauth_callback"
    WEATHERUG_KEY        = "1c6c34e969b99131"
    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new({:host => uri.host,
                        :port => uri.port,
                        :password => uri.password})
    CALLBACK_URL = "http://127.0.0.1:9292/oauth_callback"
    $redis.flushdb
    @@profiles = []
  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  ########################
  # Routes
  ########################

  get('/') do
    base_url = "https://github.com/login/oauth/authorize"
    scope    = "user"
    state    = SecureRandom.urlsafe_base64
    session[:state] = state
    @url = "#{base_url}?client_id=#{GITHUB_CLIENT_ID}&scope=#{scope}&redirect_uri=#{GITHUB_CALLBACK_URL}&state=#{state}"
    render(:erb, :index, :template =>:layout)
  end

get("/oauth_callback") do
  code = params[:code]
  if session[:state] == params[:state]
    response = HTTParty.post("https://github.com/login/oauth/access_token", :body => {
      client_id: GITHUB_CLIENT_ID,
      client_secret: GITHUB_CLIENT_SECRET,
      code: code,
      redirect_uri: "http://127.0.0.1:9292/oauth_callback"
    },
      :headers => {
      "Accept" => "application/json"
    })
    session["access_token"] = response["access_token"]
    user_info_response = HTTParty.get("https://api.github.com/user?access_token=#{session['access_token']}", headers: { "User-Agent" => "Rat Store Example" })
    # binding.pry
#     response_two = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
#     session[:access_token] = response_two.access_token
 end
  redirect to("/profile/edit")
end

get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end



get("/feeds")do

@user_one = JSON.parse($redis["profiles:0"])
#################
# NYTimes Events
#################

  @events = HTTParty.get("http://api.nytimes.com/svc/events/v2/listings.json?filters=borough:Manhattan&api-key=d580e2fba62b85adae01dbb42834ddab:6:69766004")
  @simplified_events = @events["results"]

#####################
# Weather Underground
#####################

    @city = "new_york"
    @state = "NY"
      @hourly_temperature = HTTParty.get("http://api.wunderground.com/api/#{WEATHERUG_KEY}/hourly/q/#{@state}/#{@city}.json")
      first_time = @hourly_temperature["hourly_forecast"][0]["FCTTIME"]["civil"]
      first_temp = @hourly_temperature["hourly_forecast"][0]["temp"]["english"]

###############
# Yelp
###############

      @client = Yelp::Client.new({ consumer_key: "Tk51e10C3NlC-bpMio_orA",
                            consumer_secret: "jR0kGr2xOX5GMuWZnYIlF_KGeOk",
                            token: "5rfVNLDITMRQ8JMOw1_7ULMTZ4lQW7UB",
                            token_secret: "Fm42MAHK-l_gvOKpKNCy1HYjjq8" })
                            params = { term: 'restaurant'}
      @ny_yelp = @client.search("New York", params)
      @stringy_ny_yelp = @ny_yelp.to_json
      @parsed_ny_yelp = JSON.parse(@stringy_ny_yelp)

#######################
# NYTimes Movie Reviews
#######################

@reviews = HTTParty.get("http://api.nytimes.com/svc/movies/v2/reviews/search.json?critics-pick=Y&api-key=1e0225a5429d17924a7526f4a9454f9c:10:69766004")
@simplified_reviews = @reviews["results"]

##############
# Twitter
##############

@twitter_client              = Twitter::REST::Client.new do |config|
  config.consumer_key        = "VtC6Dir0O3m0tJudSs4gdlq12"
  config.consumer_secret     = "DpF5SkcswnZxmfqlRYt4z3Mp3e7zJfPYVYDHpggNAeItEw0HbF"
  # config.access_token        = "172149629-E0uBw812dgzlkN8JT9NwKfCwnlbYg6YnJeuWlfdk"
  # config.access_token_secret = "4Cs54fbL6RRXv4Vv0E7I8tV6xYxc7tCpGO3v1gzPcb23w"
end
@tweets = @twitter_client.search("nightlife, nyc", :result_type => "recent").take(5).collect do |tweet|
      {content: "#{tweet.user.screen_name}: #{tweet.text}", url: "#{tweet.url}"}
    end
###############
# Instagram
###############
    Instagram.configure do |config|
      config.client_id = "2f02f71d330647768ec32f4da1ef1df6"
      config.client_secret = "b7014ef40e3c424e94e659632b5d866c"
    end

@ig_flicks = HTTParty.get("https://api.instagram.com/v1/media/popular?access_token=#{session['access_token']}")

  render(:erb, :dashboard, :template =>:layout)
end

get("/profile/edit")do
  render(:erb, :questionnaire, :template => :layout)
end

get("/thanks")do
  render(:erb, :thanks, :template => :layout)
end

get("/register")do
  redirect to("/profile/edit")
end

post("/profile/new") do
  profile_info = {
  :username     => params[:user_name],
  :email        => params[:user_email],
  :user_city    => params[:user_city],
  :user_state   => params[:user_state],
  :user_img     => params[:user_img],
  :user_drinks? => params[:user_drinks],
  :fandango     => params[:fandango],
  :yelp         => params[:yelp],
  :NYTE         => params[:nyte],
  :NYTMR        => params[:nytmr],
  :twitter      => params[:twitter],
  :instagram    => params[:instagram],
  :weather      => params[:weather]
}
  @@profiles.push(profile_info)
    @@profiles.each_with_index do |profile, index|
      $redis.set("profiles:#{index}", profile.to_json)
    end
      logger.info @@profiles
        redirect to("/thanks")
end

get("/profiles")do
  @profiles = @@profiles
  render(:erb, :profiles, :template => :layout)
binding.pry
end

get("/profile/:id")do
  @profiles = @@profiles
  @index = params[:id].to_i - 1
  render(:erb, :user_profile, :template => :layout)
end

get("/logout") do
session["access_token"] = nil
redirect to("/")
end


end
