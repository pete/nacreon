module Nacreon::Resource
	# Nacreon is mostly concerned with managing apps, so the App resource is
	# one of the central chunks of code.
	# FIXME:  Everywhere that AppManager is talked to directly in this code,
	# the code is wrong.  We gotta for the time being, though.
	class App < Generic
		get { |name|
			return error_401 unless authenticated?
			a = Model::App[:name => name]
			return error_404 unless a
			r = a.to_hash
			if r[:latest_version]
				r[:latest_version][:uri] =
					"/app/#{name}/version/#{r[:latest_version][:name]}"
			end
			json_resp r
		}

		put { |name|
			return error_401 unless authenticated?
			# TODO:  Authorization.
			a = Model::App[:name => name]
			return error_404 unless a
			a.set json_body
			return json_resp(a) if a.save
		}

		# A POST here requires one or more arguments:
		# 	?mode=deploy[&version=$v]
		# 		Deploys version named $v, or the latest if not specified.
		# 	?mode=kill[&version=$v]
		#		Kills the version named $v, or all versions if not specified.
		# 	?mode=cleanup
		# 		Cleans up all instances but the most recently deployed.  This
		# 		is a shortcut for finding which versions are deployed and
		# 		sending a kill for each one except the latest.
		post { |name|
			return error_401 unless authenticated?
			# TODO:  Authorization.
			a = Model::App[:name => name]
			return error_404 unless a

			v = (query['version'] ?
			     a.versions_dataset[:name => query['version']] : nil)

			case((query['mode'][0] rescue nil))
			when 'deploy'
				json_resp(deploy_version a, (v || a.latest_version))
			when 'cleanup'
				cleanup_old_versions a
			when 'kill'
				killed =
					if v
						kill_version a, v
					else
						kill_all_instances a
					end
				json_resp killed
			else
				return json_error(
					"POST requires a mode parameter: "\
					"cleanup, deploy, or kill.", 400)
			end
		}

		delete { |name|
			return error_401 unless authenticated?
			app = Model::App[:name => name]

			return error_404 unless app
			return error_403 unless app.owner_id == user.id

			# TODO:  There remains to be done stuff like killing off old
			# versions of the app, soft deletes for everything, etc.

			begin
				if app
					app.delete
				end

				# May at some point change this to 202, to avoid blocking while
				# we spin down apps.  (cf., RFC2616, 9.7)
				# TODO:  We do not currently spin them down.
				[204, {}, []]
			rescue StandardError => e
				# FIXME:  Debugging code.
				s = [e, app].inspect
				[500,
				 {
					'Content-Length' => s.bytesize.to_s,
					'Content-Type' => 'text/plain',
				 },
				 [s]]
			end
		}

		private

		def deploy_version app, version
			vname = version.name rescue version

			unless version.kind_of?(Model::Version)
				version = app.versions_dataset[:name => version]
			end
			unless version
				return :deployment_error =>
					"Version #{vname} doesn't exist for #{app.name}."
			end

			Nacreon::AppManager.prep_version version
			version.instantiate
		end

		def cleanup_old_versions app
			kill_instances(app.live_instances_dataset.
			               exclude(:version_id => app.current_version.id).to_a)
		end

		def kill_version app, version = nil
			# FIXME:  Who made that name/argument combination?  Whose idea waas
			# this?  Beat that guy with a tire iron.
			# TODO:  Remove the above comment; I made up 'kill_version app,
			# version'.  Seriously, though, it could do with a redesign.
			version ||= app.versions_dataset[:name => vname]
			unless version
				return :kill_error =>
					"Couldn't kill non-extant version #{vname}."
			end

			kill_instances version.live_instances
		end

		def kill_all_instances app
			kill_instances app.live_instances
		end

		def kill_instances is
			is.each { |i| i.marked! "Marked to be killed by user." }
			{ :instances_killed => is }
		end
	end

	class AppList < Generic
		get {
			return error_401 unless authenticated?
			apps = Model::App.all
			json_resp apps
		}

		# Not particularly married to POSTing to the app list, as a name must
		# be supplied anyway, so just a PUT to /app/name might be more
		# appropriate.
		post {
			return error_401 unless authenticated?
			unless json_body
				return json_error('No body provided, or could not parse body.')
			end

			a = Model::App.new json_body
			a.owner = user
			if !a.valid? || !a.save
				# TODO:  409 when the name is taken?
				return json_resp(a.errors, 400)
			end

			return json_resp(a, 201, 'Location' => "/app/#{a.name}")
		}

	end
end
