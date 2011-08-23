require 'rake/gempackagetask'
require 'rake/rdoctask'
require './lib/nacreon/config'

$columns = (ENV['COLUMNS'] || 80).to_i
$bundler_warned = !ENV['BUNDLER_WARNING_WARNED'].nil?

begin
	require 'bundler'
	Bundler::GemHelper.install_tasks
rescue LoadError => e
	$stderr.puts(' Bundler is not installed.  Its rake tasks won\'t work. '.
		center($columns, '*')) unless $bundler_warned
	ENV['BUNDLER_WARNING_WARNED'] = 'yep'
end

# There's a lot of awkward ENV juggling; this is to simplify that.
def in_env(h = {}, &b)
	tmp = {}
	h.each { |k,v|
		tmp[k] = ENV[k]
		ENV[k] = v
	}
	r = b[]
	tmp.each { |k,v| ENV[k] = v }
	r
end

Rake::RDocTask.new(:doc) { |t|
	t.main = 'doc/README'
	t.rdoc_files.include 'lib/**/*.rb', 'doc/*', 'bin/*', 'ext/**/*.c',
		'ext/**/*.rb'
	t.options << '-S' << '-N'
	t.rdoc_dir = 'doc/rdoc'
}

desc "Runs IRB, automatically require()ing nacreon."
task(:irb) {
	exec "irb -Ilib -rnacreon"
}

# This is getting a bit long for a Rake task.
desc "Runs tests."
task(:test) {
	integration_env = {
		'NACREON_CONF' => 'test/int/nacreon.json',
		'RUBYLIB' => (ENV['RUBYLIB'].to_s.split(':') << './lib').join(':'),
	}

	int_test_env = {
		'NACREON_CONF' => 'test/int/nacreon.json',
		'RUBYLIB' => (ENV['RUBYLIB'].to_s.split(':') <<
		              './lib' << './test/int').join(':'),
	}

	unit_env = {
		'NACREON_CONF' => 'test/unit/nacreon.json',
		'RUBYLIB' => (ENV['RUBYLIB'].to_s.split(':') <<
		              './lib' << './test/unit').join(':'),
	}

	# Clean up any unfortunate leftover processes from previous runs:
	%w(
		tmp/integration.pid
		tmp/iappman.pid
	).each { |pf|
		(Process.kill(9, File.read(pf).to_i) if File.exist?(pf)) rescue nil
	}

	# And clean up files form previous runs:
	rm '/tmp/nacreon-unit-test.db' rescue nil
	rm '/tmp/nacreon-integration-test.db' rescue nil
	rm_rf './tmp/integration-instances' rescue nil
	rm_rf './tmp/unit-deploy-root' rescue nil

	# Start up a Nacreon instance to test the full stack:
	iserv, iappman = []
	in_env(integration_env) {
		system 'rake migrate'
		iserv = spawn('unicorn -c test/int/unicorn.rb '\
					  'test/int/config.ru -p tmp/integration.pid')
		$stderr.puts "Integration test server starting as pid #{iserv}."

		iappman = spawn('bin/nacreon-app-managerd -f -o tmp/iappman.log '\
						'-p tmp/iappman.pid')
		$stderr.puts "Integration test app manager starting as pid #{iappman}."
	}

	# Start the unit tests running:
	u_reqs = Dir['test/unit/**/*_test.rb'].map { |t|
		"-r#{t.gsub('test/unit/', '')}"
	}.join(' ')

	unit = in_env(unit_env) {
		IO.popen "ruby -rtest_helper #{u_reqs} -e '' 2>&1"
	}

	# Start the integration tests running:
	i_reqs =  Dir['test/int/*_test.rb'].map { |t|
		"-r#{File.basename t, '.rb'}"
	}.join(' ')

	sleep 1
	if Process.waitpid(iserv, Process::WNOHANG)
		$stderr.puts '*' * $columns,
			"Integration test server failed to start!  Problems:",
			'*' * $columns
		$stderr.puts File.read('tmp/iserv.log')
	end

	if Process.waitpid(iappman, Process::WNOHANG)
		$stderr.puts '*' * $columns,
			"Integration app manager failed to start!  Problems:",
			'*' * $columns
		$stderr.puts File.read('tmp/iappman.log')
	end

	int = in_env(int_test_env) {
		IO.popen "ruby -rtest_helper #{i_reqs} -e '' 2>&1"
	}

	# Spit out the output from both:
	$stderr.flush
	puts ' Unit Tests '.center($columns, '_')
	while c = unit.read(1); print c; end
	puts ' Integration Tests '.center($columns, '_')
	while c = int.read(1); print c; end

	# Shut up, integration server.  We don't need your kind any more.
	Process.kill 15, iserv
	Process.kill 15, iappman
	sleep 1
	Process.kill 9, iserv
	Process.kill 9, iappman
	Process.wait iserv
	Process.wait iappman

	rm '/tmp/nacreon-unit-test.db' rescue nil
	#system 'echo .dump | sqlite3 /tmp/nacreon-integration-test.db'
	rm '/tmp/nacreon-integration-test.db' rescue nil
	rm 'tmp/iserv.pid' rescue nil
	rm 'tmp/iappman.pid' rescue nil
	rm_rf './tmp/integration-instances' rescue nil
	rm_rf './tmp/unit-deploy-root' rescue nil
}

task :default => :test

desc "Update the database with the latest schema."
task(:migrate) {
	require 'sequel'
	require 'sequel/extensions/migration'
	Nacreon::Config.load
	Sequel.connect(Nacreon::Config.db) { |db|
		Sequel::Migrator.apply(db, './migrations')
	}
}

desc "Show the database schema as SQL...in a perfect world. [FIXME]"
task(:schema) {
	require 'sequel'
	require 'pp'
	Nacreon::Config.load
	Sequel.connect(Nacreon::Config.db) { |db|
		db.tables.each { |t|
			puts "#{t}:"
			pp db.schema(t, :raw => true)
			puts ''
		}
	}
}

spec = eval File.read('nacreon.gemspec')
Rake::GemPackageTask.new(spec) { |pkg|
	pkg.need_tar_bz2 = true
}

desc "Cleans out the packaged files."
task(:clean) {
	FileUtils.rm_rf 'pkg'
}

# Unlikely to be set accidentally:
if ENV['I_DONT_NEED_BUNDLER_AS_I_DONT_USE_RVM']
	desc "Builds and installs the gem for #{spec.name}"
	task(:install => :package) {
		g = "pkg/#{spec.name}-#{spec.version}.gem"
		system "sudo gem install -l #{g}"
	}
end

desc "Run nacreon with unicorn"
task(:unicorn) {
	sh "unicorn -c conf/unicorn.rb"
}

desc "Run nacreon with unicorn in daemon mode"
task(:daemon) {
	sh "unicorn -D -c conf/unicorn.rb"
}

desc "Start up an app manager in the foreground"
task(:app_manager) {
	sh "ruby -Ilib bin/nacreon-app-managerd -f"
}

desc "Start up an app manager daemon"
task(:app_managerd) {
	sh "ruby -Ilib bin/nacreon-app-managerd"
}

task(:install_deps) {
	sh 'gem install bundler --no-rdoc --no-ri'
	sh 'bundle'
}

desc "Perform all initial setup functions."
task(:newb) {
	%w(install_deps migrate test
	  ).each do |task|
		Rake::Task[task].invoke
	end

	puts <<MSG
==============================
    So, what have you done?
        bundle installed gems, run db migrations and executed tests.

    What now?
        1. README
        2. Code stuff
        3. Submit back
        4. ???
        5. Profit!
MSG
}
