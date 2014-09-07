require 'sinatra/base'
require 'securerandom'
require 'httparty'
require 'redis'
require 'yelp'
require 'twitter'
require 'instagram'


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
session[:access_token] = response[:access_token]
  end
  redirect to("/thanks")
end

get("/dashboard")do
@events = HTTParty.get("http://api.nytimes.com/svc/events/v2/listings.json?filters=borough:Manhattan&api-key=d580e2fba62b85adae01dbb42834ddab:6:69766004")
@simplified_events = @events["results"]

@city = "new_york"
@state = "NY"
@hourly_temperature = HTTParty.get("http://api.wunderground.com/api/#{WEATHERUG_KEY}/hourly/q/#{@state}/#{@city}.json")
first_time = @hourly_temperature["hourly_forecast"][0]["FCTTIME"]["civil"]
first_temp = @hourly_temperature["hourly_forecast"][0]["temp"]["english"]

@client = Yelp::Client.new({ consumer_key: "Tk51e10C3NlC-bpMio_orA",
                            consumer_secret: "jR0kGr2xOX5GMuWZnYIlF_KGeOk",
                            token: "5rfVNLDITMRQ8JMOw1_7ULMTZ4lQW7UB",
                            token_secret: "Fm42MAHK-l_gvOKpKNCy1HYjjq8" })
params = { term: 'restaurant',
         }
@ny_yelp = @client.search("New York", params)
@stringy_ny_yelp = @ny_yelp.to_json
@parsed_ny_yelp = JSON.parse(@stringy_ny_yelp)


# @client_two = Twitter::Streaming::Client.new do |config|
#   config.consumer_key        = "VtC6Dir0O3m0tJudSs4gdlq12"
#   config.consumer_secret     = "DpF5SkcswnZxmfqlRYt4z3Mp3e7zJfPYVYDHpggNAeItEw0HbF"
#   config.access_token        = "172149629-E0uBw812dgzlkN8JT9NwKfCwnlbYg6YnJeuWlfdk"
#   config.access_token_secret = "4Cs54fbL6RRXv4Vv0E7I8tV6xYxc7tCpGO3v1gzPcb23w"
# end
# @topics = ["coffee", "tea"]

# Instagram.configure do |config|
#   config.client_id = "2f02f71d330647768ec32f4da1ef1df6"
#   config.client_secret = "b7014ef40e3c424e94e659632b5d866c"
# end

render(:erb, :dashboard, :template =>:layout)
end

get("/questionnaire")do
render(:erb, :questionnaire, :template => :layout)
end

get("/thanks")do
render(:erb, :thanks, :template => :layout)
end

get("/register")do
redirect to("/questionnaire")
end

post("/profile/new") do
# include array of member profile info
redirect to("/thanks")
end



end
