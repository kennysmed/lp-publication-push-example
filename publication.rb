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
  # Use something like:
  #   access_token.post(config['endpoint'], content,
  #                               'Content-Type' => 'text/html; charset=utf-8')
  def access_token
    @access_token ||= OAuth::AccessToken.new(
                        consumer,
                        settings.bergcloud_access_token,
                        settings.bergcloud_access_token_secret)
  end

  # Returns the Redis object (either new or existing).
  def redis
    @redis ||= new_redis
  end

  # Make a new Redis object either from a URL in settings, or a local server.
  def new_redis
    begin
      # If there is a redis_url setting present.
      uri = URI.parse(settings.redis_url)
      Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    rescue NoMethodError
      # Otherwise, use a local server (we assume there is one).
      Redis.new()
    end
  end
end


get '/' do
  return 'A Little Printer publication.'
end


# == POST parameters:
# :config
#   params[:config] contains a JSON array of responses to the options defined
#   by the fields object in meta.json. In this case, something like:
#   params[:config] = ["name":"SomeName", "lang":"SomeLanguage"]
# :endpoint
#   the URL to POST content to be printed out by Push.
# :subscription_id
#   a string used to identify the subscriber and their Little Printer.
#
# Most of this is identical to a non-Push publication.
# The only difference is that we have an `endpoint` and `subscription_id` and
# need to store this data in our database. All validation is the same.
#
# == Returns:
# A JSON response object.
# If the parameters passed in are valid: {"valid":true}
# If the parameters passed in are not valid: {"valid":false,"errors":["No name was provided"], ["The language you chose does not exist"]}
#
post '/validate_config/' do
  if params[:config].nil?
    return 400, 'There is no config to validate.'
  end

  # Preparing what will be returned:
  response = {
    :errors => [],
    :valid => true
  }

  # Extract the config from the POST data and parse its JSON contents.
  # user_settings will be something like: {"name":"Alice", "lang":"english"}.
  user_settings = JSON.parse(params[:config])

  # If the user did not choose a language:
  if user_settings['lang'].nil? || user_settings['lang'] == ''
    response[:valid] = false
    response[:errors] << 'Please choose a language from the menu.'
  end
  
  # If the user did not fill in the name option:
  if user_settings['name'].nil? || user_settings['name'] == ''
    response[:valid] = false
    response[:errors] << 'Please enter your name into the name box.'
  end
  
  unless settings.greetings.include?(user_settings['lang'].downcase)
    # Given that the select field is populated from a list of languages
    # we defined this should never happen. Just in case.
    response[:valid] = false
    response[:errors] << "We couldn't find the language you selected (#{user_settings['lang']}). Please choose another."
  end

  ########################
  # This section is Push-specific, different to a conventional publication:

  # Check we have received an endpoint and subscription ID.
  if params[:endpoint].nil? || params[:endpoint] == ''
    response[:valid] = false
    response[:errors] << 'No Push endpoint was provided.'
  end
  if params[:subscription_id].nil? || params[:subscription_id] == ''
    response[:valid] = false
    response[:errors] << 'No Push subscription_id was provided.'
  end

  if response[:valid]
    # Assuming the form validates, we store the endpoint, plus this user's
    # language choice and name, keyed by their subscription_id.
    user_settings[:endpoint] = params[:endpoint]
    redis.hset('push_example:subscriptions',
                params[:subscription_id], user_settings.to_json)
  end
  # Ending the Push-specific section.
  ########################
  
  content_type :json
  response.to_json
end


# Called to generate the sample shown on BERG Cloud Remote.
#
# == Parameters:
#   None.
#
# == Returns:
# HTML/CSS edition.
#
get '/sample/' do
  language = 'english';
  name = 'Little Printer';
  @greeting = "#{settings.greetings[language][0]}, #{name}"
  # Set the ETag to match the content.
  etag Digest::MD5.hexdigest(language + name + Time.now.utc.strftime('%d%m%Y'))
  erb :edition
end


# A button to press to send print events to subscribed Little Printers.
get '/push/' do
  erb :push, :locals => {:pushed => false}
end


# When the button is pressed, this happens.
# Push a greeting to all subscribed Little Printers.
post '/push/' do
  subscribed_count = 0
  unsubscribed_count = 0
  redis.hgetall('push_example:subscriptions').each_pair do |subscription_id, config|
    # config contains the subscriber's language, name and endpoint.
    config = JSON.parse(config)
    p config

    # Get a random greeting in this subscriber's chosen language.
    @greeting = "#{settings.greetings[config['lang']].sample}, #{config['name']}"

    # Make the HTML content to push to the printer.
    content = erb :edition

    begin
      # Post this content to BERG Cloud using OAuth.
      res = access_token.post(config['endpoint'], content,
                              'Content-Type' => 'text/html; charset=utf-8')
      if res.code == '410'
        # By sending a 410 status code, BERG Cloud has informed us this
        # user has unsubscribed. So delete their subscription from our
        # database.
        redis.hdel('push_example:subscriptions', subscription_id)
        unsubscribed_count += 1
      else
        subscribed_count += 1
      end
    end
  end

  # Show the same form again, with a message to confirm this worked.
  erb :push, :locals => {:pushed => true,
                         :subscribed_count => subscribed_count,
                         :unsubscribed_count => unsubscribed_count}
end
