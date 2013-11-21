Push API Sample Publication
==============================

## In progress

`config.yml` should be like:

	bergcloud_consumer_token: yourConsumerToken
	bergcloud_consumer_token_secret: yourConsumerTokenSecret
	bergcloud_access_token: yourAccessToken
	bergcloud_access_token_secret: yourAccessTokenSecret
	bergcloud_site: http://api.bergcloud.com

Optional:

	redis_url: yourRedisURL


If not, then in ENV vars:
	
	BERGCLOUD_CONSUMER_TOKEN
	BERGCLOUD_CONSUMER_TOKEN_SECRET
	BERGCLOUD_ACCESS_TOKEN
	BERGCLOUD_ACCESS_TOKEN_SECRET
	BERGCLOUD_SITE

Optional:

	REDIS_URL




This is a fork of the Hello World publication that will push random greetings on demand to a Little Printer

It probably mostly works, the API isn't guaranteed to be stable yet.


Requirements
------------

This example requires a redis-server running in order to store the subscriptions endpoint urls

Copy `auth.yml.example` to `auth.yml` and fill in your BERG Cloud OAuth tokens. These are found on your publication's page at http://remote.bergcloud.com/developers/publications/

----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/
