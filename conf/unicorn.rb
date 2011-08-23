listen "localhost:4999"
worker_processes 4
pid "/tmp/unicorn-nacreon.pid"
#stderr_path "/tmp/unicorn-nacreon.log"
#stdout_path "/tmp/unicorn-nacreon.log"
preload_app false
