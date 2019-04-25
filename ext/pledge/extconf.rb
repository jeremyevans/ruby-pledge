require 'mkmf'
have_header 'unistd.h'
have_func('pledge') || raise("pledge(2) not present, cannot built extension")
have_func('unveil')
$CFLAGS << " -O0 -g -ggdb" if ENV['DEBUG']
$CFLAGS << " -Wall"
create_makefile("pledge")
