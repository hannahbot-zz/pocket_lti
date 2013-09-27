require 'sinatra'
require 'json'
require 'net/http'
require 'net/https'

class PocketLti < Sinatra::Base
  POCKET_URL               = 'https://getpocket.com/v3'
  POCKET_REQUEST_URL       = '/oauth/request'
  POCKET_AUTHORIZE_URL     = '/oauth/authorize'
  POCKET_RETRIEVE_URL      = '/get'
  CONSUMER_KEY             = '18846-f8d8e6d9af4a26e611f5a834'
  REDIRECT_URI             = 'http://localhost:3000/oauth/response'
  LTI_LAUNCH_URL           = 'http://localhost:3000/lti_launch'

  # Use sessions to store user data
  enable :sessions
  set :session_secret, 'super secret session key'

  # Allow the app to be embedded in an iframe
  set :protection, except: :frame_options

  get '/' do
    return pocket_request(POCKET_RETRIEVE_URL, count: 5).to_json

    "<a href='/oauth/launch'>Click Here to login to Pocket.</a>"
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

  get '/oauth/launch' do
    if pocket_access_token
      redirect '/'
      return
    end

    pocket_response = pocket_request(POCKET_REQUEST_URL, redirect_uri: REDIRECT_URI)
    session[:pocket_code] = pocket_response['code']

    puts "Got Code: #{pocket_code}"

    redirect "https://getpocket.com/auth/authorize?request_token=#{pocket_code}&redirect_uri=#{REDIRECT_URI}"
  end

  get '/oauth/response' do
    puts "Get Code: #{session[:pocket_code]}"

    raise "Could not find Pocket Code" unless pocket_code

    pocket_response = pocket_request(POCKET_AUTHORIZE_URL, code: pocket_code)

    session[:pocket_access_token] = pocket_response['access_token']
    session[:pocket_username]     = pocket_response['username']

    puts "Got Access Token: #{pocket_access_token}"

    redirect '/'
  end

  # Handle POST requests to the endpoint "/lti_launch"
  post "/lti_launch" do
    "<a href='/oauth/launch'>Click Here to login to Pocket.</a>"
  end

  #XML CONFIG
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
          <blti:description>Save stuff from Canvas to Pocket</blti:description>
          <blti:icon>http://3doordigital.com/wp-content/uploads/Pocket-icon-e1358620226390.png</blti:icon>
          <blti:extensions platform="canvas.instructure.com">
            <lticm:property name="tool_id">pocketi_lti</lticm:property>
            <lticm:property name="privacy_level">public</lticm:property>
            <lticm:options name="editor_button">
              <lticm:property name="url">http://localhost:3000/lti_launch</lticm:property>
              <lticm:property name="icon_url">http://3doordigital.com/wp-content/uploads/Pocket-icon-e1358620226390.png</lticm:property>
              <lticm:property name="text">Get Pocket</lticm:property>
              <lticm:property name="selection_width">400</lticm:property>
              <lticm:property name="selection_height">300</lticm:property>
              <lticm:property name="enabled">true</lticm:property>
            </lticm:options>
            <lticm:options name="resource_selection">
              <lticm:property name="url">http://localhost:3000/lti_launch</lticm:property>
              <lticm:property name="icon_url">http://3doordigital.com/wp-content/uploads/Pocket-icon-e1358620226390.png</lticm:property>
              <lticm:property name="text">Pocket LTI</lticm:property>
              <lticm:property name="selection_width">400</lticm:property>
              <lticm:property name="selection_height">300</lticm:property>
              <lticm:property name="enabled">true</lticm:property>
            </lticm:options>
            <lticm:options name="course_navigation">
              <lticm:property name="url">http://localhost:3000/lti_launch</lticm:property>
              <lticm:property name="text">Pocket LTI</lticm:property>
              <lticm:property name="visibility">public</lticm:property>
              <lticm:property name="default">enabled</lticm:property>
              <lticm:property name="enabled">true</lticm:property>
            </lticm:options>
          </blti:extensions>
          <cartridge_bundle identifierref="BLTI001_Bundle"/>
          <cartridge_icon identifierref="BLTI001_Icon"/>
      </cartridge_basiclti_link>
    EOF
  end

  private

  def pocket_request(path, body_hash = {})
    # Parse URI
    pocket_uri = URI.parse(POCKET_URL)

    # Create https object
    https = Net::HTTP.new(pocket_uri.host, pocket_uri.port)

    # Set to use SSL
    https.use_ssl = true

    # Create request
    request = Net::HTTP::Post.new("#{pocket_uri.path}#{path}")

    # Add consumer key to json submit data
    body_hash.merge!(consumer_key: CONSUMER_KEY)

    # # Add access token if we already have it
    body_hash[:access_token] = pocket_access_token if pocket_access_token

    # Set request body
    request.body = body_hash.to_json

    # Set request headers
    request['Content-Type'] = 'application/json; charset=UTF-8'
    request['X-Accept'] = 'application/json'

    puts "Request: #{path} >> #{request.body}"

    # Get Response from pocket
    response = https.request(request)

    # Throw an error if something was wrong with the request.
    # if response.code != 200
    #   halt erb fail_alert("Could not fetch list from Pocket.  There was an error.  #{response.code}")
    # end

    puts "Response: #{path} >> #{response.body}"

    # Parse response body as json and return the hash.
    JSON.parse(response.body)
  end

  def pocket_code
    session[:pocket_code]
  end

  def pocket_access_token
    session[:pocket_access_token]
  end

  def pocket_username
    session[:pocket_username]
  end
end