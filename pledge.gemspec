Gem::Specification.new do |s|
  s.name = 'pledge'
  s.version = '1.2.0'
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG", "MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'pledge: restrict system operations and file system access on OpenBSD', '--main', 'README.rdoc']
  s.summary = "Restrict system operations and file system access on OpenBSD"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.homepage = "https://github.com/jeremyevans/ruby-pledge"
  s.required_ruby_version = ">= 1.9.2"
  s.files = %w(MIT-LICENSE CHANGELOG README.rdoc Rakefile ext/pledge/extconf.rb ext/pledge/pledge.c spec/pledge_spec.rb lib/unveil.rb)
  s.license = 'MIT'
  s.extensions << 'ext/pledge/extconf.rb'
  s.description = <<END
pledge exposes OpenBSD's pledge(2) and unveil(2) system calls to Ruby, allowing
a program to restrict the types of operations the program can do, and the file
system access the program has, after the point of call.  Unlike other similar
systems, pledge and unveil are specifically designed for programs that need to
use a wide variety of operations on initialization, but a fewer number after
initialization (when user input will be accepted).
END
  s.add_development_dependency "minitest-global_expectations"
end
