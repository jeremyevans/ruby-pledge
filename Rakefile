require "rake"
require "rake/clean"

CLEAN.include %w'**.rbc rdoc'

desc "Do a full cleaning"
task :distclean do
  CLEAN.include %w'tmp pkg tame*.gem lib/*.so'
  Rake::Task[:clean].invoke
end

desc "Build the gem"
task :package do
  sh %{gem build pledge.gemspec}
end

desc "Run specs"
task :spec => :compile do
  ruby = ENV['RUBY'] ||= FileUtils::RUBY 
  sh %{#{ruby} spec/pledge_spec.rb}
end

desc "Run specs"
task :default => :spec

begin
  require 'rake/extensiontask'
  Rake::ExtensionTask.new('pledge')
rescue LoadError
end
