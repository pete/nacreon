require 'test/unit'
require 'net/http'
require 'json'

TestAdmin = { :username => 'testadmin', :password => rand.to_s }

# Just a set of things to provide easy HTTP access to the server.  Copypasta
# from Beekeeper, with some stuff cut out, and assertions added to spot where
# we have failed to comply with the spec.
module HTTPHelpers
	attr_accessor :username, :password

	def http req
		r = nil
		req.basic_auth username, password
		Net::HTTP.new('localhost', 21245).start { |http|
			r = http.request req
		}
		validate_http_response! r
		r
	end

	def get path
		http Net::HTTP::Get.new(path)
	end

	def delete path
		http Net::HTTP::Delete.new(path)
	end

	def post path, body = nil
		r = Net::HTTP::Post.new path
		r.body = body
		http r
	end

	def put path, body = nil
		r = Net::HTTP::Put.new path
		r.body = body
		http r
	end

	def try_json req
		r = nil
		assert_nothing_raised { r = JSON.parse req.body.to_s }
		r
	end

	# Runs some appropriate assertions to validate the response per RFC 2616
	# (where we can verify it), plus the slightly more strict "Let's make sure
	# that we do provide Location in relevant 3xx responses" rule.
	def validate_http_response! resp
		if resp['content-length']
			assert_equal resp['content-length'].to_i, resp.body.to_s.bytesize,
				"Content-length mis-match in reply!"
		end

		c = resp.code.to_i

		case c
		when 100, 101, 305, 402, 407, 500..505
			assert false,
				"Nacreon is not supposed to return HTTP status code #{c}."
		when 200, 202, 203, 300, 400, 403, 404, 406, 408..411, 414..417
			# There's not a lot that is both required and verifiable for these
			# statuses.
		when 201
			assert_has_header resp, 'location'
		when 204
			assert_empty_body resp
		when 205
			assert_empty_body resp
		when 206
			assert_has_header resp, 'content-range'
			assert_has_header resp, 'date'
		when 301, 302, 307
			# Technically not *required* by the spec, but I feel pretty
			# good about ensuring that these responses have a Location.
			assert_has_header resp, 'location'
		when 304
			assert_empty_body resp
		when 401
			assert_has_header resp, 'www-authenticate'
		when 405
			assert_has_header resp, 'allow'
		else
			assert false, "Nacreon returned invalid HTTP/1.1 status code #{c}!"
		end
	end

	def assert_has_header resp, name
		assert_not_nil resp[name],
			"A #{resp.code} response must contain a #{name.capitalize} header!"
	end

	def assert_hasnt_header resp, name
		assert_nil resp[name], "A #{resp.code} response must not "\
			"contain a #{name.capitalize} header!"
	end

	def assert_empty_body resp
		assert_equal 0, resp.body.to_s.bytesize,
			"A #{resp.code} response must not contain a body!"
	end
end

class Test::Unit::TestCase
	include HTTPHelpers

	def use_admin_user!
		self.username, self.password =
			TestAdmin[:username], TestAdmin[:password]
	end

	def blank_user!
		self.username, self.password = nil, nil
	end

	def teardown
		blank_user!
	end

	def test_app_tarball
		return @test_app_tarball if @test_app_tarball

		@test_app_tarball =
			`cd test/data/hello-rack; tar -cf - config.ru | gzip`
	end
end

bootstrapper =
	IO.popen("bin/nacreon-bootstrap-user #{TestAdmin[:username]}", 'r+')
2.times { bootstrapper.puts TestAdmin[:password] }
bootstrapper.read
