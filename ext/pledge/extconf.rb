require 'mkmf'
have_header 'unistd.h'
have_func('pledge')
have_func('unveil')
$CFLAGS << " -O0 -g -ggdb" if ENV['DEBUG']
$CFLAGS << " -Wall"
create_makefile("pledge")
