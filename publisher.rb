require 'yaml'
require 'oauth'

class Publisher

  def initialize
    config = YAML.load_file('auth.yml')
    consumer = OAuth::Consumer.new(config['consumer_token'], config['consumer_token_secret'], :site => config['site'])
    @access_token = OAuth::AccessToken.new(consumer, config['access_token'], config['access_token_secret'])
  end

  def push_to_bergcloud(endpoint, content)
    @access_token.post(endpoint, content, "Content-Type" => "text/html; charset=utf-8")
  end

end

if __FILE__ == $0
  endpoint = ARGV.shift
  raise "Push endpoint URL is needed" unless endpoint
  puts "Pushing to #{endpoint}"
  res = Publisher.new.push_to_bergcloud(endpoint, ARGF.read)
  puts "response: #{res.code}"
end
