class UserTest < Test::Unit::TestCase
	def test_crud_and_logins
		resp = get '/user'
		assert_equal 401, resp.code.to_i

		use_admin_user!

		resp = get '/user'
		assert_equal 200, resp.code.to_i
		users = try_json resp
		names = users.map { |u| u['name'] }
		assert names.include?(username), "The admin ought to be a valid user."

		bill = {'name' => 'bill', 'password' => 'asdfjkl;'}
		resp = post '/user', bill.to_json
		assert_equal 201, resp.code.to_i
		bill2 = try_json resp
		assert_equal bill['name'], bill2['name']
		assert_nil bill2['password']
		assert_nil bill2['hashed_password']
		path = resp['location']

		resp = get path
		assert_equal 200, resp.code.to_i
		bill3 = try_json resp
		assert_equal bill2, bill3, "What we get on creation ought to be "\
			"what we get when we GET the user."

		# We should be able to log in as Bill and do things now.
		self.username, self.password = bill['name'], bill['password']
		resp = get '/app'
		assert_equal 200, resp.code.to_i

		# Bill can delete himself.
		resp = delete path
		assert_equal 204, resp.code.to_i, "No content when we delete."

		# But he can't see anything after he does:
		resp = get '/user'
		assert_equal 401, resp.code.to_i,
			"Deleted users shouldn't have authorization!"

		use_admin_user!
		resp = get path
		assert_equal 404, resp.code.to_i, "Deleted users shouldn't hang around."
		# TODO:  410 is more appropriate after implementing soft delete.
	end
end
