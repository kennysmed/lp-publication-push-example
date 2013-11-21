# encoding: UTF-8
require 'json'
require 'oauth'
require 'redis'
require 'sinatra'
require 'sinatra/config_file'


configure do
  set :greetings, {
    'english'     => ['Hello', 'Hi'], 
    'french'      => ['Salut'], 
    'german'      => ['Hallo', 'Tag'], 
    'spanish'     => ['Hola'], 
    'portuguese'  => ['Olá'], 
    'italian'     => ['Ciao'], 
    'swedish'     => ['Hallå']
  }

  # Reads in settings from the YAML file and makes them available.
  # Or, if there isn't one, from ENV variables.
  if File.exists?('./config.yml') 
    config_file './config.yml'
  else
    set :bergcloud_consumer_token, ENV['BERGCLOUD_CONSUMER_TOKEN']
    set :bergcloud_consumer_token_secret, ENV['BERGCLOUD_CONSUMER_TOKEN_SECRET']
    set :bergcloud_access_token, ENV['BERGCLOUD_ACCESS_TOKEN']
    set :bergcloud_access_token_secret, ENV['BERGCLOUD_ACCESS_TOKEN_SECRET']
    set :bergcloud_site, ENV['BERGCLOUD_SITE']

    if ENV['REDIS_URL']
      set :redis_url, ENV['REDIS_URL']
    else
      set :redis_url, nil
    end
  end
end


helpers do
  # The BERG Cloud OAuth consumer object.
  def consumer
    @consumer ||= OAuth::Consumer.new(
                    settings.bergcloud_consumer_token,
                    settings.bergcloud_consumer_token_secret,
                    :site => settings.bergcloud_site)
  end

  # The BERG Cloud OAuth access token.
  def access_token
    @access_token ||= OAuth::AccessToken.new(
                        consumer,
                        settings.bergcloud_access_token,
                        settings.bergcloud_access_token_secret)
  end

  def redis
    @redis ||= new_redis
  end

  # Make a new Redis object either from a URL in settings, or a local server.
  def new_redis
    if settings.redis_url.nil?
      Redis.new()
    else
      uri = URI.parse(settings.redis_url)
      Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    end
  end
end


# Returns a sample of the publication. Triggered by the user hitting 'print sample' on you publication's page on BERG Cloud.
#
# == Parameters:
#   None.
#
# == Returns:
# HTML/CSS edition with etag. This publication changes the greeting depending on the time of day. It is using UTC to determine the greeting.
#
get '/sample/' do
  language = 'english';
  name = 'Little Printer';
  @greeting = "#{settings.greetings[language][0]}, #{name}"
  # Set the etag to be this content
  etag Digest::MD5.hexdigest(language+name)
  erb :hello_world
end


# Validate that the config settings are correct and store the subscription info for future use
#
# == Parameters:
# :config
#   params[:config] contains a JSON array of responses to the options defined by the fields object in meta.json.
#   in this case, something like:
#   params[:config] = ["name":"SomeName", "lang":"SomeLanguage"]
# :endpoint
#   the URL to POST content to be printed out
# :subscription_id
#   a random string used to identify the subscription and it's printer
#
# == Returns:
# a response json object.
# If the paramters passed in are valid: {"valid":true}
# If the paramters passed in are not valid: {"valid":false,"errors":["No name was provided"], ["The language you chose does not exist"]}"
#
post '/validate_config/' do
  response = {}
  response[:errors] = []
  response[:valid] = true
  
  if params[:config].nil?
    return 400, "You did not post any config to validate"
  end
  # Extract config from POST
  user_settings = JSON.parse(params[:config])

  # If the user did choose a language:
  if user_settings['lang'].nil? || user_settings['lang']==""
    response[:valid] = false
    response[:errors].push('Please select a language from the select box.')
  end
  
  # If the user did not fill in the name option:
  if user_settings['name'].nil? || user_settings['name']==""
    response[:valid] = false
    response[:errors].push('Please enter your name into the name box.')
  end
  
  unless settings.greetings.include?(user_settings['lang'].downcase)
    # Given that that select box is populated from a list of languages that we have defined this should never happen.
    response[:valid] = false
    response[:errors].push("We couldn't find the language you selected (#{user_settings['lang']}) Please select another")
  end

  user_settings[:endpoint] = params[:endpoint]

  if response[:valid]
    redis.hset('push_example:subscriptions', params[:subscription_id], user_settings.to_json)
  end
  
  content_type :json
  response.to_json
end

# a button to press to send print events to subscriptions
get '/push/' do
  erb :push, :locals => {:pushed => false}
end

post '/push/' do
  redis.hgetall('push_example:subscriptions').each_pair do |id, config|
    config = JSON.parse(config)
    endpoint = config['endpoint']
    greeting = "#{settings.greetings[config['lang']].sample}, #{config['name']}"
    content = erb :hello_world, :locals => {:greeting => greeting}
    begin
      res = access_token.post(endpoint, content, "Content-Type" => "text/html; charset=utf-8")
      if res.code == "410"
        redis.hdel('push_example:subscriptions', id)
      end
    end
  end
  erb :push, :locals => {:pushed => true}
end
