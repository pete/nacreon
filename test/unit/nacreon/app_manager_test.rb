require 'net/http'

# This test is not very unit-y
class Nacreon::AppManagerTest < Test::Unit::TestCase
	include Nacreon

	def setup
		@spare_pids = []
	end

	def test_startup
		a, u, v1 = app_user_version
		assert_nothing_raised { AppManager.save_tarball v1, test_app_tarball }

		filename = AppManager.tarball_for(v1)
		assert_not_nil filename
		assert(system("tar -tf #{filename} >/dev/null 2>/dev/null"))

		tarball = nil
		assert_nothing_raised { tarball = File.read(filename) }
		assert_not_nil tarball

		i = AppManager.deploy(v1)
		@spare_pids << i.pid
		assert_equal Model::Instance, i.class

		# In the case that the "Hello, World!" app fails to start in time, we
		# want to give it a second.
		begin
			Net::HTTP.get(URI.parse("http://localhost:#{i.port}/"))
		rescue Errno::ECONNREFUSED
			sleep AppManager.startup_timeout
		end

		assert AppManager.instance_listening?(i),
			"Instance with pid #{i.pid} should be listening on port #{i.port}!"

		assert_nothing_raised {
			Net::HTTP.get(URI.parse("http://localhost:#{i.port}/"))
		}

		i.reload
		i2 = Model::Instance[i.id]
		assert_equal 'started', i.status

		begin
			AppManager.kill i
		rescue Nacreon::AppManager::RProxy::StartupError
			# Ignore this error; we're not running any reverse proxies in the
			# unit tests.
		end
	end

	def teardown
		super
		@spare_pids.each { |p|
			Process.kill 9, p rescue nil
			Process.waitpid p rescue nil
		}
	end
end
