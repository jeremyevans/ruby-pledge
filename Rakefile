require "rake/clean"

CLEAN.include %w'lib/*.so tmp coverage'

desc "Build the gem"
task :package do
  sh %{gem build pledge.gemspec}
end

desc "Run specs"
task :spec => :compile do
  sh %{#{FileUtils::RUBY} #{"-w" if RUBY_VERSION >= '3'} #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} spec/pledge_spec.rb}
end

desc "Run specs"
task :default => :spec

desc "Run specs with coverage"
task :spec_cov => [:compile] do
  ruby = ENV['RUBY'] ||= FileUtils::RUBY 
  ENV['COVERAGE'] = '1'
  FileUtils.rm_rf('coverage')
  sh %{#{ruby} spec/unveil_spec.rb}
end

begin
  require 'rake/extensiontask'
  Rake::ExtensionTask.new('pledge')
rescue LoadError
end
