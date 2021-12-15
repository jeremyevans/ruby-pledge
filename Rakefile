require "rake"
require "rake/clean"

CLEAN.include %w'**.rbc rdoc lib/*.so tmp'

desc "Build the gem"
task :package do
  sh %{gem build pledge.gemspec}
end

desc "Run specs"
task :spec => :compile do
  ruby = ENV['RUBY'] ||= FileUtils::RUBY 
  sh %{#{ruby} #{"-w" if RUBY_VERSION >= '3'} spec/pledge_spec.rb}
end

desc "Run specs"
task :default => :spec

begin
  require 'rake/extensiontask'
  Rake::ExtensionTask.new('pledge')
rescue LoadError
end
