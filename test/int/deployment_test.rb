require 'digest/md5'

class DeploymentTest < Test::Unit::TestCase
	# Tests a successful deployment; it exercises the whole thing, with the
	# exception of errors.
	#
	# TODO:  Test permissions at various steps, the case where app won't
	# start, the case where we submit an invalid app, trying to deploy a
	# specific version, trying to deploy the wrong version, trying to deploy
	# without versions, etc.
	# TODO:  Factor this test so that we can jump ahead to the various steps
	# without copypasta.
	def test_deployment
		use_admin_user!

		resp = get '/app'
		assert_equal 200, resp.code.to_i
		apps = try_json resp

		new_app = {
			# Name doesn't matter, but it's unlikely we'll collide with another
			# name if we make an MD5 of the text of all version names.
			'name' => Digest::MD5.hexdigest(resp.body),
			'owner_name' => username,
		}

		resp = post '/app', new_app.to_json
		assert_equal 201, resp.code.to_i
		path = resp['location']
		assert_not_nil path

		resp = get path
		assert_equal 200, resp.code.to_i

		resp = get "#{path}/version"
		assert_equal 200, resp.code.to_i
		versions = try_json resp
		assert_equal [], versions

		v1 = { 'name' => 'v1' }
		resp = put "#{path}/version/v1", test_app_tarball
		assert_equal 201, resp.code.to_i,
			"New version, so Nacreon is supposed to return 201.  " <<
				resp.body.to_s[0..40].inspect
		v1r = try_json resp
		assert v1r.has_key?('name')
		assert_equal 'v1', v1r['name']

		resp = post "#{path}?mode=deploy"
		assert_equal 200, resp.code.to_i
		inst = try_json resp
		assert_equal 'ready', inst['status']

		# It should totally be the case that the simplest Rack app starts in
		# under a second.  We're going to wait for two for the AppManager to
		# bring it up.
		sleep 200

		resp = get path
		a = try_json resp
		assert_equal 1, a['live_instances'].size

		respk = post "#{path}?mode=kill"
		a = try_json respk
		assert_equal 1, a.inspect
	end
end
