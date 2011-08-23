ENV['NACREON_CONF'] = File.expand_path("#{File.dirname(__FILE__)}/nacreon.json")
system 'rake migrate'

require 'test/unit'
require 'nacreon'
require 'timecop'
require 'logger'

Nacreon.log = Logger.new("tmp/unit.log")

class Test::Unit::TestCase
	def fake_user opts = {}
		default = {
			:name => 'fake-user',
			:password => 'asdf',
		}
		u = Nacreon::Model::User.new default.merge(opts)
		assert u.valid?
		u
	end


	def fake_app user, opts = {}
		default = {
			:name => 'fake-app',
			:owner_name => user.name,
		}
		a = Nacreon::Model::App.new default.merge(opts)
		assert a.valid?
		a
	end

	def app_and_user
		u = fake_user
		assert u.save
		a = fake_app u
		assert a.save
		[a, u]
	end

	def app_user_version
		a, u = app_and_user
		v = a.add_version_named 'v1'
		[a, u, v]
	end

	def clear_db!
		%w(Instance Version App User).each { |c|
			Nacreon::Model.const_get(c).delete
		}
	end

	# We store times in the DB at 1-second resolution.  This is fine for
	# everything except tests, when you do things like create different
	# instances of different versions within a second and expect sorting to
	# behave.
	def advance_1sec!
		Timecop.travel(Time.now + 1)
	end

	def teardown
		clear_db!
		Timecop.return
	end

	def test_app_tarball
		return @test_app_tarball if @test_app_tarball

		@test_app_tarball =
			`cd test/data/hello-rack; tar -cf - config.ru | gzip`
	end
end
