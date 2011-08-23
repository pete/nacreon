# The unicorn config for individual applications started by Nacreon.
username = `id -nu`.strip
worker_processes 2
preload_app true
stdout_path "/tmp/nacreon-app.#{username}.#{$$}.log"
stderr_path "/tmp/nacreon-app.#{username}.#{$$}.log"
