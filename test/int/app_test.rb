class AppTest < Test::Unit::TestCase
	def test_crud
		# Unauthenticated users should get 401 regardless of whether the app
		# exists:
		resp = get '/app/test-app'
		assert_equal 401, resp.code.to_i, "Unauthenticated users shouldn't "\
			"be able to determine if an app exists."

		# And not be able to make apps:
		resp = post('/app',
		            {'name' => 'test-app', 'owner_name' => username}.to_json)

		assert_equal 401, resp.code.to_i,
			"Unauthenticated users shouldn't be able to make apps."

		use_admin_user!

		resp = get '/app/test-app'
		assert_equal 404, resp.code.to_i, "The app shouldn't exist yet!"

		# Create the app:
		resp = post('/app',
		            {'name' => 'test-app', 'owner_name' => username}.to_json)
		assert_equal 201, resp.code.to_i,
			"The app should have been successfully created."
		app = try_json(resp)

		# Check the response:
		assert_equal 'test-app', app['name'],
			"The app's name ought to be as set in the request."
		assert_equal username, app['owner_name'],
			"The app created by us ought to have our username as the owner."
		assert app.has_key?('live_instances'),
			"An app ought to list live instances."
		assert_equal [], app['live_instances'],
			"New app shouldn't have live instances."

		resp = delete('/app/test-app')
		assert_equal 204, resp.code.to_i, "No content when we delete."

		resp = delete('/app/test-app')
		assert_equal 404, resp.code.to_i, "Deleted apps shouldn't hang around."
		# TODO:  410 is more appropriate after we add 'deleted' flag to apps.
	end
end
