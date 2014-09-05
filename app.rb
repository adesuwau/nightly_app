require 'sinatra/base'
require 'securerandom'
require 'httparty'


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
  redirect to("/dashboard")
end

get("/dashboard")do
@events = HTTParty.get("http://api.nytimes.com/svc/events/v2/listings.json?filters=borough:Manhattan&api-key=d580e2fba62b85adae01dbb42834ddab:6:69766004")
@simplified_events = @events["results"]

@city = "new_york"
@state = "NY"
@hourly_temperature = HTTParty.get("http://api.wunderground.com/api/#{WEATHERUG_KEY}/hourly/q/#{@state}/#{@city}.json")
first_time = @hourly_temperature["hourly_forecast"][0]["FCTTIME"]["civil"]
first_temp = @hourly_temperature["hourly_forecast"][0]["temp"]["english"]
render(:erb, :dashboard, :template =>:layout)
end

# get("/profile") do
# render(:erb, :profile)
# end
end
