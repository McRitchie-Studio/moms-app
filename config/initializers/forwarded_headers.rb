# WHICH PROXY HEADER NAMES THE CLIENT, for Rails' request.remote_ip.
#
# Rack 3 reads the standard `Forwarded` header BEFORE `X-Forwarded-For`, and the
# Heroku router neither sets nor strips `Forwarded`, so a caller could write
#
#     Forwarded: for=203.0.113.9
#
# and be counted as that address, a new one on each request. The sign-in rate
# limit (ClosedSignup::MagicLinkRequest) keys on remote_ip, so without this line
# it could be dodged with one header.
#
# The router DOES control X-Forwarded-For: it appends the address it saw to the
# right of the list, and Rack and Rails walk the list from the right, so a value
# the client put on the left is never reached
# (https://devcenter.heroku.com/articles/http-routing). A request with no
# `Forwarded` header, which is every browser, is read exactly as before.
#
# Same fix as turf-monster's config/initializers/forwarded_headers.rb. If a proxy
# that speaks `Forwarded` is ever put in front of the router, revisit this.
# test/integration/closed_signup_test.rb holds the property.
Rack::Request.forwarded_priority = [ :x_forwarded ]
