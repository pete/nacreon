class Nacreon::Model::InstanceTest < Test::Unit::TestCase
	include Nacreon::Model

	def test_starting_and_stopping
		a, u = app_and_user
		v = a.add_version_named 'a'
		assert_equal 0, v.live_instance_count

		i = v.instantiate
		assert_equal 0, v.live_instance_count
		assert_equal 0, Instance.live_dataset.count
		assert !i.live?
		i.started!
		assert !i.live?

		i.live!
		assert_equal 1, v.live_instance_count
		assert v.live_instances.include?(i)
		assert_equal 1, Instance.live_dataset.count
		assert i.live?

		i.killed!
		assert !i.live?
		assert_equal 0, v.live_instance_count
		assert_equal 0, Instance.live_dataset.count

		i = v.instantiate
		assert_equal 0, v.live_instance_count
		assert_equal 0, Instance.live_dataset.count

		i.dead!
		assert_equal 0, v.live_instance_count
		assert_equal 0, Instance.live_dataset.count
		assert !i.live?
	end
end
