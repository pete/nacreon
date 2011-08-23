require 'rubygems'

libdir = "#{Dir.pwd}/lib"
$: << File.expand_path(libdir) if File.directory?(libdir)

require 'nacreon'

begin
	Nacreon::AppManager.start_rproxies
rescue Exception => e
	$stderr.puts "Couldn't start the reverse proxies for some reason:",
		e.inspect, *e.backtrace
end
app = Nacreon::App.new
builder = Rack::Builder.new {
	use Rack::Reloader, 1
	use Rack::ShowExceptions
	run app
}.to_app
run builder
