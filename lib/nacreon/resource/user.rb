module Nacreon::Resource
	class UserList < Generic
		get {
			return error_401 unless authenticated?
			json_resp(Model::User.all)
		}

		# See the comments for AppList#post
		post {
			return error_401 unless authenticated?

			unless json_body
				return json_error('No body provided, or could not parse body.')
			end

			body = json_body
			u = Model::User.new json_body

			if !u.valid? || !u.save
				# TODO:  409 when the name is taken.
				return json_resp({'errors' => u.errors}, 400)
			end

			return json_resp(u, 201, 'Location' => "/user/#{u.name}")
		}
	end

	class User < Generic
		get { |name|
			return error_401 unless authenticated?
			u = Model::User[:name => name]
			return error_404 unless u
			json_resp u
		}

		put { |name|
			return error_401 unless authenticated?
			return error_403 unless user.name == name #|| user.admin? #TODO
			u = Model::User[:name => name]
			return error_404 unless u
			json_body.delete 'admin'
			u.set json_body
			return json_resp(u) if u.save
		}

		delete { |name|
			return error_401 unless authenticated?
			return error_403 unless user.name == name #|| user.admin? #TODO
			u = Model::User[:name => name]
			return error_404 unless u
			u.delete
			[204, {}, []]
		}
	end
end
