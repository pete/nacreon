class Nacreon::Model::UserTest < Test::Unit::TestCase
	include Nacreon::Model

	def test_auth
		name = 'asdf'
		pass = 'asdfjkl;'

		u = User.new
		u.name = name
		u.password = pass
		assert u.save

		assert_equal User[:name => name], User.authenticate(name, pass)
		assert_nil User.authenticate(name, pass + 'nope')
		assert_nil User.authenticate(name + 'nope', pass)
	end
end
