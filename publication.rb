require 'sinatra'
require 'json'
require 'redis'

require './publisher'

publisher = Publisher.new


# Define some general greetings
greetings = {"english" => ["Hello", "Hi"],
    "french" => ["Salut"],
    "german" => ["Hallo" "Tag"],
    "spanish" =>["Hola"],
    "portuguese" => ["Ol&#225;"],
    "italian" => ["Ciao"],
    "swedish"=>["Hall&#229;"]}

# Somewhere to store subscriptions
db = Redis.new

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
  @greeting = "#{greetings[language].sample}, #{name}"
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
  
  unless greetings.include?(user_settings['lang'].downcase)
    # Given that that select box is populated from a list of languages that we have defined this should never happen.
    response[:valid] = false
    response[:errors].push("We couldn't find the language you selected (#{user_settings['lang']}) Please select another")
  end

  user_settings[:endpoint] = params[:endpoint]

  if response[:valid]
    db.hset('push_example:subscriptions', params[:subscription_id], user_settings.to_json)
  end
  
  content_type :json
  response.to_json
end

# a button to press to send print events to subscriptions
get '/push/' do
  erb :push, :locals => {:pushed => false}
end

post '/push/' do
  db.hgetall('push_example:subscriptions').each_pair do |id, config|
    config = JSON.parse(config)
    endpoint = config['endpoint']
    greeting = "#{greetings[config['lang']].sample}, #{config['name']}"
    content = erb :hello_world, :locals => {:greeting => greeting}
    begin
      res = publisher.push_to_bergcloud(endpoint, content)
      if res.code == "410"
        db.hdel('push_example:subscriptions', id)
      end
    end
  end
  erb :push, :locals => {:pushed => true}
end
