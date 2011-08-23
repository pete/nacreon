# Nacreon::App is the entry point for the web-app part; it maps URIs to
# resources and is passed to Rack, so if you want to know everything from the
# beginning, it's best to start here.
class Nacreon::App < Watts::App
	include Nacreon::Resource

	resource('/', Discovery) {
		resource("app", AppList) {
			resource(NameRX, App) {
				resource('version', VersionList) {
					resource(URLSafeRX, Version)
				}
			}
		}

		resource("user", UserList) {
			resource(NameRX, User)
		}
	}
end
