require 'rubygems'

libdir = "#{Dir.pwd}/lib"
$: << File.expand_path(libdir) if File.directory?(libdir)

require 'nacreon'

app = Nacreon::App.new
builder = Rack::Builder.new {
	use Rack::Reloader, 1
	use Rack::ShowExceptions
	run app
}.to_app
run builder
