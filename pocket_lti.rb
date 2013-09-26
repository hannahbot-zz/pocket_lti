begin
  require 'rubygems'
rescue LoadError
  puts "You must install rubygems to run this example"
  raise
end

begin
  require 'bundler/setup'
rescue LoadError
  puts "to set up this example, run these commands:"
  puts "  gem install bundler"
  puts "  bundle install"
  raise
end

require 'sinatra'

# Sinatra wants to set x-frame-options by default, disable it
disable :protection
# Enable sessions so we can remember the launch info between http requests, as
# the user takes the assessment
enable :sessions

require 'json'
require 'net/http'

  # Configure the application here

  # LTI settings
  CONSUMER_KEY    = 'key'
  CONSUMER_SECRET = 'secret'

  # OAuth settings
  POCKET_URL      = 'https://getpocket.com/v3/oauth/request'
  CLIENT_ID       = '1'
  CLIENT_SECRET   = '18846-f8d8e6d9af4a26e611f5a834'
  REDIRECT_URI    = 'http://localhost:5000/oauth2response'

  # Use sessions to store user data
  enable :sessions

  # Allow the app to be embedded in an iframe
  set :protection, except: :frame_options

  # In a real application, these would be persistent. We'd also need to
  # encrypt the user tokens, because they're as valuable as a password.
  @@nonce_cache = []
  @@token_cache = {}

  # Return a list of the current user's courses.
  get '/' do
    courses_api     = URI("#{POCKET_URL}/api/v1/courses?access_token=#{current_token}")
    canvas_response = Net::HTTP.get(courses_api)
    @courses        = JSON.parse(canvas_response)

    erb :index
  end

  # Unless we've already got an API token, begin the OAuth process. Otherwise,
  # redirect to the app's main page.
  get '/oauth/launch' do
    redirect current_token ? '/' : "#{POCKET_URL}/login/oauth2/auth?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URI}"
  end

  # Handle the OAuth redirect from Canvas. Make a POST request back to Canvas
  # to finish the OAuth process and save the token we receive.
  get '/oauth2response' do
    pocket_url = URI("#{POCKET_URL}/login/oauth2/token")
    response = Net::HTTP.post_form(pocket_url, client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, client_secret: CLIENT_SECRET, code: params[:code])
    @@token_cache[session[:user]] = JSON.parse(response.body)['access_token']

    redirect '/'
  end

  private

  # Helper to retrieve the current user's API token.
  def current_token
    @@token_cache[session[:user]]
  end

# Handle POST requests to the endpoint "/lti_launch"
#post "/lti_launch" do
get "/lti_launch" do
#pocket stuff
end

get "/config.xml" do
  headers 'Content-Type' => 'text/xml'
  <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<cartridge_basiclti_link xmlns="http://www.imsglobal.org/xsd/imslticc_v1p0"
    xmlns:blti = "http://www.imsglobal.org/xsd/imsbasiclti_v1p0"
    xmlns:lticm ="http://www.imsglobal.org/xsd/imslticm_v1p0"
    xmlns:lticp ="http://www.imsglobal.org/xsd/imslticp_v1p0"
    xmlns:xsi = "http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation = "http://www.imsglobal.org/xsd/imslticc_v1p0 http://www.imsglobal.org/xsd/lti/ltiv1p0/imslticc_v1p0.xsd
    http://www.imsglobal.org/xsd/imsbasiclti_v1p0 http://www.imsglobal.org/xsd/lti/ltiv1p0/imsbasiclti_v1p0.xsd
    http://www.imsglobal.org/xsd/imslticm_v1p0 http://www.imsglobal.org/xsd/lti/ltiv1p0/imslticm_v1p0.xsd
    http://www.imsglobal.org/xsd/imslticp_v1p0 http://www.imsglobal.org/xsd/lti/ltiv1p0/imslticp_v1p0.xsd">
    <blti:title>Pocket LTI</blti:title>
    <blti:description>Pocket LTI Description</blti:description>
    <blti:icon>#{ request.scheme }://#{ request.host_with_port }/icon.png</blti:icon>
    <blti:extensions platform="canvas.instructure.com">
      <lticm:property name="tool_id">pocket_lti</lticm:property>
      <lticm:property name="privacy_level">anonymous</lticm:property>
      <lticm:options name="editor_button">
        <lticm:property name="url">#{ request.scheme }://#{ request.host_with_port }/lti_launch</lticm:property>
        <lticm:property name="text">Pocket LTI</lticm:property>
        <lticm:property name="selection_width">450</lticm:property>
        <lticm:property name="selection_height">350</lticm:property>
        <lticm:property name="enabled">true</lticm:property>
      </lticm:options>
    </blti:extensions>
    <cartridge_bundle identifierref="BLTI001_Bundle"/>
    <cartridge_icon identifierref="BLTI001_Icon"/>
</cartridge_basiclti_link>  
  EOF
end

# NOTE: When we pull out the traditional LTI, a db isn't even needed anymore!