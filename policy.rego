package test

default allow = false

# input.http_request
# * id string -- X-Request-ID
# * method string -- HTTP request method, e.g. GET, POST, ...
# * headers map[string]string -- lowercased HTTP request headers
# * path string -- HTTP URL path
# * host string -- HTTP request 'Host' or 'Authority'
# * scheme string -- HTTP URL scheme, e.g. 'http' or 'https'
# * query string -- HTTP URL query in form or 'name1=value&name2=value2'
# * fragment string -- HTTP URL fragment exlcuind leading '#'
# * size_ int64 -- HTTP request size in bytes
# * protocol string -- network protocol, e.g. 'http/1.1', 'h2'

# allow {
# 	input.http_request.path == "/ws/countries.wsdl"
# }

allow {
	input.http_request.headers.ver == "V2"
}

allow {
	startswith(input.http_request.path, "/ws")
	input.http_request.headers.ver == "V1"
	token.payload.azp == "e79e48af-0e57-49d2-8318-d7da7c903584"
}

allow {
	startswith(input.http_request.path, "/hello")
	input.http_request.headers.ver == "V1"
	token.payload.azp == "952de292-f39b-4574-addb-5b51d0d221e1"
}

# Helper to get the token payload
token = {"payload": payload} {
	# split header authorization value string 'Bearer <jwt>'
	output := split(input.http_request.headers.authorization, " ")
	[header, payload, signature] := io.jwt.decode(output[1])
}
