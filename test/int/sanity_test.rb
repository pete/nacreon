class SanityTest < Test::Unit::TestCase
	def test_discovery
		use_admin_user!

		resp = get '/'
		assert_equal 200, resp.code.to_i
		r = try_json(resp)
		assert_equal({'users' => '/user', 'apps' => '/app'}, r)
	end
end
