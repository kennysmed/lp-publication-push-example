# Little Printer Push API example (Ruby)

This is an example publication written in Ruby using the [Sinatra](http://www.sinatrarb.com/) framework.

This example expands on the Hello World example, and demonstrates how to use the Push API to send messages directly to subscribed Little Printers.


## Configuration

This example requires a Redis server running in order to store the data about subscriptions. If no URL is supplied, then it will use a local server with no authentication.

You will need to get the BERG Cloud OAuth authentication tokens from the page for your newly-created Little Printer publication (in [Your publications](http://remote.bergcloud.com/developers/publications/)).

Configuration details can be set either in a `config.yml` file (copy `config.yml.example`) or in environment variables.

`config.yml` should be like:

	bergcloud_consumer_token: yourConsumerToken
	bergcloud_consumer_token_secret: yourConsumerTokenSecret
	bergcloud_access_token: yourAccessToken
	bergcloud_access_token_secret: yourAccessTokenSecret
	bergcloud_site: http://api.bergcloud.com

If you have a Redis URL, add that:

	redis_url: redis://username:password@your.redis.server:12345

If using enivronment variables, these are the same, but capitalised:
	
	BERGCLOUD_CONSUMER_TOKEN
	BERGCLOUD_CONSUMER_TOKEN_SECRET
	BERGCLOUD_ACCESS_TOKEN
	BERGCLOUD_ACCESS_TOKEN_SECRET
	BERGCLOUD_SITE

And the Redis URL:

	REDIS_URL

If a `config.yml` file is present, its contents will be used in place of any environment variables.

## Run it

Run the server with:

	$ rackup

You can then visit these URLs:

	* `/icon.png`
	* `/meta.json`
	* `/sample/`
	* `/push/`

The `/push/` page lets you send a greeting to all subscribed Little Printers.

In addition, the `/validate_config/` URL should accept a POST request with a field named `config` containing a string like:

	{"lang":"english", "name":"Phil", "endpoint": "http://api.bergcloud.com/v1/subscriptions/2ca7287d935ae2a6a562a3a17bdddcbe81e79d43/publish", "subscription_id": "2ca7287d935ae2a6a562a3a17bdddcbe81e79d43"}

but with a unique `endpoint` and `subscription_id`.


----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/

