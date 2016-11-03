require 'mkmf'
have_header 'pledge'
$CFLAGS << " -O0 -g -ggdb" if ENV['DEBUG']
$CFLAGS << " -Wall"
create_makefile("pledge")
