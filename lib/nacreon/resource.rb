require 'nacreon/model'
require 'cgi'

module Nacreon::Resource
	include Nacreon

	# The Generic resource, with some utility methods for the other Nacreon
	# resources.
	class Generic < Watts::Resource
		include Nacreon

		# A few simple error messages first:

		def error_401
			json_error 'Unauthorized', 401,
				'WWW-Authenticate' => "Basic realm=\"#{Nacreon::Config.domain}\""
		end

		def error_403
			json_error 'Forbidden', 403
		end

		def error_404
			json_error 'Not Found', 404
		end

		# Returns the body given with the request, as with a POST or PUT.
		def req_body
			@req_body ||= env['rack.input'].read
		end

		# Returns the req_body, run through the JSON parser.  Returns nil if we
		# can't parse it.
		def json_body
			@json_body ||=
				begin
					JSON.parse(req_body)
				rescue JSON::ParserError
					nil
				end
		end

		# Turns the body to JSON and returns the specified status.  Takes care
		# of headers.
		def json_resp body, status = 200, headers = {}
			js = body.to_json

			[status,
				{ 'Content-Type' => 'application/json',
				  'Content-Length' => js.bytesize.to_s,
				}.merge(headers),
			 [js]]
		end

		# Returns an error with the specified status as a simiple JSON object.
		def json_error err, status = 400, headers = {}
			json_resp({'error' => err}, status, headers)
		end

		# Returns the query string, all parsed and everything.
		def query
			return @query if @query

			@query = CGI.parse(request.query_string)
			@query.default = nil # ruby/lib/cgi/core.rb:340 = den of iniquity.
			@query
		end

		# Returns a Model::User, nil to indicate no auth data, or false to
		# indicate that the user could not be authorized.
		def authenticate
			cred = env['HTTP_AUTHORIZATION']
			return nil unless cred
			username, password = basic_decode cred
			return nil unless username && password

			Model::User.authenticate username, password
		end

		def basic_decode cred
			return nil unless /^Basic (.{4,})/.match(cred)
			$1.unpack('m')[0].split(/:/, 2)
		end

		def user
			@user ||= authenticate
		end

		def authenticated?
			!user.nil?
		end
	end

	# The basic class for allowing discovery of the relevant paths by a GET /:
	class Discovery < Generic
		get { |*_|
			json_resp 'apps' => '/app', 'users' => '/user'
		}
	end
end

%w(
	app
	version
	user 
).each { |f| require "nacreon/resource/#{f}" }
