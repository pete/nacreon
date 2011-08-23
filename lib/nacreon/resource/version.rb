module Nacreon::Resource
	class Version < Generic
		get { |app_name, vname|
			return error_401 unless authenticated?
			app = Model::App[:name => app_name]
			v = Model::Version[:name => vname, :app_id => app.id]
			return error_404 unless v
			# TODO:  Authorization.
			json_resp(v)
		}

		put { |app_name, vname|
			return error_401 unless authenticated?

			unless NameRX.match(vname)
				return json_error(
					"Not Found.  (The likely culprit is the malformed "\
					"version name #{vname.inspect}.  It must contain only "\
					"alphanumeric characters and hyphens.", 404)
			end

			app = Model::App[:name => app_name]
			return error_404 unless app

			v = app.add_version_named vname

			tarball = env['rack.input'].read
			if(tarball.to_s.empty? || !AppManager.save_tarball(v, tarball))
				return json_error(
					"The request body must be a gzipped tarball!", 400)
			end

			unless v.valid?
				return json_resp({'errors' => v.errors}, 400)
			end

			json_resp v, 201, 'Location' => "/app/#{app_name}/version/#{vname}"
		}
	end

	class VersionList < Generic
		get { |name|
			return error_401 unless authenticated?
			a = Model::App[:name => name]
			return error_404 unless a
			# TODO:  Authentication, authorization.
			json_resp(a.versions)
		}
	end
end
