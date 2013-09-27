require 'sinatra'
require 'json'
require 'net/http'
require 'net/https'

class PocketLti < Sinatra::Base
  POCKET_URL               = 'https://getpocket.com/v3'
  POCKET_REQUEST_URL       = '/oauth/request'
  POCKET_AUTHORIZE_URL     = '/oauth/authorize'
  POCKET_RETRIEVE_URL      = '/get'
  CONSUMER_KEY             = '18859-ea35af14bd5e6fb981c6f8e7'
  REDIRECT_URI             = 'http://localhost:3000/oauth/response'

  # Use sessions to store user data
  enable :sessions
  set :session_secret, 'super secret session key'

  get '/' do
    if pocket_access_token
      pocket_request(POCKET_RETRIEVE_URL, count: 5).to_json
      return
    end

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