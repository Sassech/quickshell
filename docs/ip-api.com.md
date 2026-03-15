logo
Documentation
Sign up
Contact
IP Geolocation - JSON endpoint
The API base path is
http://ip-api.com/json/{query}

{query} can be a single IPv4/IPv6 address or a domain name. If you don't supply a query the current IP address will be used.

Parameters
Query parameters (such as custom fields and JSONP callback) are appended as GET request parameters, for example:
http://ip-api.com/json/?fields=61439

fields	response fields optional
lang	response language optional
callback	wrap inside (JSONP) optional
There is no API key required.

Quick test
You can edit this query and experiment with the options

GET
http://ip-api.com/json/24.48.0.1
Response
{
  "query": "24.48.0.1",
  "status": "success",
  "country": "Canada",
  "countryCode": "CA",
  "region": "QC",
  "regionName": "Quebec",
  "city": "Montreal",
  "zip": "H1K",
  "lat": 45.6085,
  "lon": -73.5493,
  "timezone": "America/Toronto",
  "isp": "Le Groupe Videotron Ltee",
  "org": "Videotron Ltee",
  "as": "AS5769 Videotron Ltee"
}
Returned data
The API can return the following fields and values

If you don't require all the returned fields, use the GET parameter fields to specify which data should be returned.
Separate the fields by comma (fields=status,message,query,country,city) or use a generated, numeric value (to save bandwidth)

name	description	example	type
	status	success or fail	success	string
	message	included only when status is fail
Can be one of the following: private range, reserved range, invalid query	invalid query	string
	continent	Continent name	North America	string
	continentCode	Two-letter continent code	NA	string
	country	Country name	United States	string
	countryCode	Two-letter country code ISO 3166-1 alpha-2	US	string
	region	Region/state short code (FIPS or ISO)	CA or 10	string
	regionName	Region/state	California	string
	city	City	Mountain View	string
	district	District (subdivision of city)	Old Farm District	string
	zip	Zip code	94043	string
	lat	Latitude	37.4192	float
	lon	Longitude	-122.0574	float
	timezone	Timezone (tz)	America/Los_Angeles	string
	offset	Timezone UTC DST offset in seconds	-25200	int
	currency	National currency	USD	string
	isp	ISP name	Google	string
	org	Organization name	Google	string
	as	AS number and organization, separated by space (RIR). Empty for IP blocks not being announced in BGP tables.	AS15169 Google Inc.	string
	asname	AS name (RIR). Empty for IP blocks not being announced in BGP tables.	GOOGLE	string
	reverse	Reverse DNS of the IP (can delay response)	wi-in-f94.1e100.net	string
	mobile	Mobile (cellular) connection	true	bool
	proxy	Proxy, VPN or Tor exit address	true	bool
	hosting	Hosting, colocated or data center	true	bool
	query	IP used for the query	173.194.67.94	string
generated fields
status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query
http://ip-api.com/json/{query}?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query

generated numeric
61439
http://ip-api.com/json/{query}?fields=61439
Localization
Localized city, regionName and country can be requested by setting the GET parameter lang to one of the following:

lang (ISO 639)	description
en	English (default)
de	Deutsch (German)
es	Español (Spanish)
pt-BR	Português - Brasil (Portuguese)
fr	Français (French)
ja	日本語 (Japanese)
zh-CN	中国 (Chinese)
ru	Русский (Russian)
Callback (JSONP)
By default there is no callback function called, but you can supply your own with the GET parameter callback

Example: http://ip-api.com/json/{query}?callback={callback}

Human usage
You can call ip-api.com, without /json/, from cURL, Wget and other CLI HTTP clients and get colourized, pretty printed JSON

Example: curl ip-api.com or curl ip-api.com/{query}

SSL (HTTPS)
256-bit SSL encryption is not available for this free API. Please see our pro service.

Usage limits
This endpoint is limited to 45 requests per minute from an IP address.

If you go over the limit your requests will be throttled (HTTP 429) until your rate limit window is reset. If you constantly go over the limit your IP address will be banned for 1 hour.

The returned HTTP header X-Rl contains the number of requests remaining in the current rate limit window. X-Ttl contains the seconds until the limit is reset.
Your implementation should always check the value of the X-Rl header, and if its is 0 you must not send any more requests for the duration of X-Ttl in seconds.

We do not allow commercial use of this endpoint. Please see our pro service for SSL access, unlimited queries and commercial support.

JavaScript code examples

// An example script for redirecting users from USA to https://google.com/
// and users from Canada to https://google.ca/

// ip-api endpoint URL
// we need only the countryCode, but you can request more fields
// see http://ip-api.com/docs/api:json for documentation
var endpoint = 'http://ip-api.com/json/?fields=status,message,countryCode';

var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function() {
	if (this.readyState == 4 && this.status == 200) {
		var response = JSON.parse(this.responseText);
		if(response.status !== 'success') {
			console.log('query failed: ' + response.message);
			return
		}
		// Redirect
		if(response.countryCode == "US") {
			window.location.replace("https://google.com/");
		}
		if(response.countryCode == "CA") {
			window.location.replace("https://google.ca/");
		}
	}
};
xhr.open('GET', endpoint, true);
xhr.send();
// An example script for finding out the distance from the user to multiple points

// Coordinates and name
var coords = [
	{lat: 40.7127837, lon: -74.0059413, name: 'New York, NY'},
	{lat: 34.0522342, lon: -118.2436849, name: 'Los Angeles, CA'},
	{lat: 37.3382082, lon: -121.8863286, name: 'San Jose, CA'},
	{lat: 41.8781136, lon: -87.6297982, name: 'Chicago, IL'},
	{lat: 47.6062095, lon: -122.3320708, name: 'Seattle, WA'},
	];

// ip-api endpoint URL
// see http://ip-api.com/docs/api:json for documentation
var endpoint = 'http://ip-api.com/json/?fields=status,message,lat,lon';

function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
	var R = 6371; // Radius of the earth in km
	var dLat = deg2rad(lat2-lat1);  // deg2rad below
	var dLon = deg2rad(lon2-lon1); 
	var a = 
		Math.sin(dLat/2) * Math.sin(dLat/2) +
		Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
		Math.sin(dLon/2) * Math.sin(dLon/2); 
	var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
	var d = R * c; // Distance in km
	return d;
}

function deg2rad(deg) {
	return deg * (Math.PI/180)
}

var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function() {
	if(this.readyState == 4 && this.status == 200) {
		var response = JSON.parse(this.responseText);
		if(response.status !== 'success') {
			console.log('query failed: ' + response.message);
			return
		}
		// Distance in kilometers for each coordinate
		for(var i = 0; i < coords.length; i++) {
			var diff = getDistanceFromLatLonInKm(coords[i].lat, coords[i].lon, response.lat, response.lon);
			console.log('distance to ' + coords[i].name + ': ' + diff + 'km');
		}
	}
};
xhr.open('GET', endpoint, true);
xhr.send();
Go pro
Get unlimited queries, SSL and commercial use

 
Response Formats
JSON
XML
CSV
Newline
PHP
API
Batch API
DNS API
Data Correction
logo
© 2022 ip-api.com. All rights reserved.
Terms and Policies
Service status