require 'simplecov'

SimpleCov.instance_exec do
  coverage :line
  coverage :branch
  cover "lib/**/*.rb"
  group('Missing'){|src| src.covered_percent < 100}
  merge_subprocesses

  at_fork do |pid|
    command_name "#{SimpleCov.command_name} (subprocess: #{pid})"
    self.print_error_status = false
    formatter SimpleCov::Formatter::SimpleFormatter
    minimum_coverage 0
    start rescue nil
  end

  if ENV['COVERAGE'] == 'subprocess'
    command_name 'spawn'
    at_fork.call(Process.pid)
  else
    ENV['COVERAGE'] = 'subprocess'
    ENV['RUBYOPT'] = "#{ENV['RUBYOPT']} -r ./spec/coverage_helper"
    start
  end
end
