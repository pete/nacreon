class Nacreon::Model::AppTest < Test::Unit::TestCase
	include Nacreon::Model

	def test_permissions
		u = fake_user
		assert u.save
		u2 = fake_user :name => 'fake2'
		assert u2.save

		a = fake_app u, :name => 'permissible'

		assert a.save
		assert a.permissible?(u)
		assert !a.permissible?(u2)

		a.owner_name = u2.name
		assert_equal u2, a.owner
		assert a.permissible?(u2)
		assert !a.permissible?(u)
	end

	def test_versions
		a, u = app_and_user

		v = a.add_version_named 'asdf'
		assert_equal 'asdf', v.name
		assert_equal v, a.latest_version
		assert_equal ['asdf'], a.version_names
	end

	def test_instance_management
		a, u, v1 = app_user_version

		advance_1sec!
		v2 = a.add_version_named 'v2'

		advance_1sec!
		v3 = a.add_version_named 'v3'

		advance_1sec!

		assert_equal v3, a.latest_version
		assert_equal nil, a.current_version

		iv2 = v2.instantiate
		iv2.started!
		iv2.live!
		assert_equal 1, a.live_instance_count
		assert_equal v2, a.current_version

		advance_1sec!
		iv3 = v3.instantiate
		iv3.started!
		iv3.live!
		assert_equal 2, a.live_instance_count
		assert_equal 2, a.live_instances.size
		assert_equal v3, a.current_version
	end
end
