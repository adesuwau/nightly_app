require 'sinatra/base'
require 'securerandom'
require 'httparty'
require 'redis'
require 'yelp'
require 'twitter'
require 'instagram'
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
    GITHUB_CLIENT_ID     = ENV['GITHUB_CLIENT_ID']
    GITHUB_CLIENT_SECRET = ENV['GITHUB_CLIENT_SECRET']
    GITHUB_CALLBACK_URL  = "http://frozen-crag-8244.herokuapp.com/oauth_callback"
    WEATHERUG_KEY        = ENV['WUNDERGROUND_API_KEY']
    MEETUP_KEY           = ENV['MEETUP_API_KEY']
    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new({:host => uri.host,
                        :port => uri.port,
                        :password => uri.password})
    CALLBACK_URL = "http://frozen-crag-8244.herokuapp.com/oauth_callback"
    @@profiles    = []
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
    @url = "#{base_url}?client_id=#{GITHUB_CLIENT_ID}&scope=#{scope}&redirect_uri=#{CALLBACK_URL}&state=#{state}"
    render(:erb, :index, :template =>:layout)
  end

get("/oauth_callback") do
  code = params[:code]
  if session[:state] == params[:state]
    response = HTTParty.post("https://github.com/login/oauth/access_token", :body => {
      client_id: GITHUB_CLIENT_ID,
      client_secret: GITHUB_CLIENT_SECRET,
      code: code,
      redirect_uri: "http://frozen-crag-8244.herokuapp.com/oauth_callback"
    },
      :headers => {
      "Accept" => "application/json"
    })
    session["access_token"] = response["access_token"]
    @@user_info_response = HTTParty.get("https://api.github.com/user?access_token=#{session['access_token']}", headers: { "User-Agent" => "Rat Store Example" })

  session["username"] = @@user_info_response["login"]
#     response_two = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
#     session[:access_token] = response_two.access_token
  end
  redirect to("/profile/edit")
end

get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get("/feeds")do
  @user = JSON.parse($redis["profiles:#{session["username"]}"])
  @profile = "/profile/" + "#{session["username"]}"
  @user_city  = @user["user_city"]
  @user_state = @user["user_state"]
  #################
  # NYTimes Events
  #################
  @events = HTTParty.get("http://api.nytimes.com/svc/events/v2/listings.json?filters=borough:Manhattan&api-key=d580e2fba62b85adae01dbb42834ddab:6:69766004")
  @simplified_events = @events["results"]

  #####################
  # Weather Underground
  #####################
    @city = @user_city.to_s.gsub(" ", "_")
    @state = @user_state
      @hourly_temperature = HTTParty.get("http://api.wunderground.com/api/#{WEATHERUG_KEY}/hourly/q/#{@state}/#{@city}.json")
      first_time = @hourly_temperature["hourly_forecast"][0]["FCTTIME"]["civil"]
      first_temp = @hourly_temperature["hourly_forecast"][0]["temp"]["english"]
###############
# Yelp
###############
@yelp_city = @user_city
      @client = Yelp::Client.new({ consumer_key: ENV['YELP_CONSUMER_KEY'],
                            consumer_secret: ENV['YELP_CONSUMER_SECRET'],
                            token: ENV['YELP_TOKEN'],
                            token_secret: ENV['YELP_TOKEN_SECRET'] })
                            params = { term: 'restaurant'}
      @ny_yelp = @client.search("#{@yelp_city}", params)
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
@twitter_city = @user_city
@twitter_client              = Twitter::REST::Client.new do |config|
  config.consumer_key        = "VtC6Dir0O3m0tJudSs4gdlq12"
  config.consumer_secret     = "DpF5SkcswnZxmfqlRYt4z3Mp3e7zJfPYVYDHpggNAeItEw0HbF"
  # config.access_token        = "172149629-E0uBw812dgzlkN8JT9NwKfCwnlbYg6YnJeuWlfdk"
  # config.access_token_secret = "4Cs54fbL6RRXv4Vv0E7I8tV6xYxc7tCpGO3v1gzPcb23w"
end
@tweets = @twitter_client.search("nightlife, #{@twitter_city}", :result_type => "recent").take(5).collect do |tweet|
      {content: "#{tweet.user.screen_name}: #{tweet.text}", url: "#{tweet.url}"}
    end
###############
# Instagram
###############
    Instagram.configure do |config|
      config.client_id = ENV['INSTAGRAM_CLIENT_ID']
      config.client_secret = ENV['INSTAGRAM_CLIENT_SECRET']
    end

@ig_flicks = HTTParty.get("https://api.instagram.com/v1/media/popular?access_token=#{session['access_token']}")
##############
# Meetup
##############
@user_zip = @user["user_zip"]

@meetup_hash = HTTParty.get("https://api.meetup.com/2/open_events.xml?zip=#{@user_zip}&time=-1d,&amp;status=past&key=#{MEETUP_KEY}")

@simplified_meetup_hash = @meetup_hash["results"]["items"]["item"]

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
    :nickname     => params[:nickname],
    :email        => params[:user_email],
    :user_city    => params[:user_city],
    :user_state   => params[:user_state],
    :user_zip     => params[:user_zip],
    :user_drinks? => params[:user_drinks],
    :meetup       => params[:meetup],
    :yelp         => params[:yelp],
    :NYTE         => params[:nyte],
    :NYTMR        => params[:nytmr],
    :twitter      => params[:twitter],
    :instagram    => params[:instagram],
    :weather      => params[:weather]
  }
  @@profiles.push(profile_info)
  @@profiles.each  do |profile|
    $redis.set("profiles:#{session['username']}", profile.to_json)
  end
  logger.info @@profiles
  redirect to("/thanks")
end

get("/profiles")do
  @profiles = @@profiles
  render(:erb, :profiles, :template => :layout)
end

get("/profile/:id")do
  @user = JSON.parse($redis["profiles:#{session["username"]}"])
  params[:id] = @user["username"]
  @user_info_response = @@user_info_response
  render(:erb, :user_profile, :template => :layout)
end

get("/logout") do
session["access_token"] = nil
redirect to("/bye")
end

get("/bye")do
render(:erb, :bye, :template => :layout)
end

end
