if ENV.delete('COVERAGE')
  Dir.mkdir('coverage') unless File.directory?('coverage')
  require_relative 'coverage_helper'
end

require 'rbconfig'
require_relative '../lib/pledge'

ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'

RUBY = RbConfig.ruby

describe "Pledge.unveil" do
  if ENV['COVERAGE']
    def unveil_code(code)
      <<END
require './lib/unveil'
mod = Module.new do
  def unveil_without_lock(hash)
    hash['coverage'] = 'rwc'
    super(hash)
  end
end
Pledge.send(:extend, mod)
#{code}
END
    end
  else
    def unveil_code(code)
      "require './lib/unveil'\n#{code}"
    end
  end

  def unveiled(unveils, code)
    run_unveil(unveil_code("Pledge.unveil(#{unveils.inspect}); #{code}"))
  end

  def run_unveil(code)
print '.'
    system(RUBY, '--disable-gems', '-e', unveil_code(code))
  end

  test_file = "spec/#{$$}_test.rb"

  after do
    File.delete(test_file) if File.file?(test_file)
  end

  it "should handle unveiling paths" do
    unveiled({}, "exit(Dir['*'].empty?)").must_equal true
    unveiled({'.'=>'r'}, "exit(!Dir['*'].empty?)").must_equal true

    test_read = "exit(((File.read('MIT-LICENSE'); true) rescue false))"
    unveiled({'.'=>'w'}, test_read).must_equal false
    unveiled({'.'=>'r'}, test_read).must_equal true
    unveiled({'.'=>'r'}, "exit(((File.open('MIT-LICENSE', 'w'){}; true) rescue false))").must_equal false

    %w'rwxc rwx rwc rxc rx rw rc'.each do |perm|
      unveiled({'.'=>perm}, test_read).must_equal true
    end

    %w'wxc wx wc xc x w c'.each do |perm|
      unveiled({'.'=>perm}, test_read).must_equal false
    end

    unveiled({'MIT-LICENSE'=>'r'}, test_read).must_equal true
    unveiled({'Rakefile'=>'r'}, test_read).must_equal false
    unveiled({'.'=>'r', 'MIT-LICENSE'=>''}, test_read).must_equal false
    unveiled({}, "Pledge.unveil{} rescue exit(1)").must_equal false
    run_unveil("Pledge.unveil_without_lock({'.'=>'r'}); Pledge.unveil({}); #{test_read}").must_equal true
    run_unveil("Pledge.unveil('foo/bar'=>'r') rescue exit(1)").must_equal false
    run_unveil("Pledge.send(:_unveil, '.', 'f') rescue exit!(1)").must_equal false
    run_unveil("Pledge.unveil({1=>'s'}) rescue exit(1)").must_equal false
    run_unveil("Pledge.unveil({'s'=>1}) rescue exit(1)").must_equal false
    run_unveil("Pledge.send(:_unveil, 1, 'r') rescue exit!(1)").must_equal false
    run_unveil("Pledge.send(:_unveil, '.', 1) rescue exit!(1)").must_equal false
  end

  it "should handle require after unveil with read access after removing from $LOADED_FEATURES" do
    [File.join('.', test_file), File.join(Dir.pwd, test_file)].each do |f|
      f = f.inspect
     run_unveil(<<-END).must_equal true
        File.open(#{f}, 'w'){|f| f.write '1'}
        require #{f}
        Pledge.unveil('spec'=>'r')
        $LOADED_FEATURES.delete #{f}
        require #{f}
      END
    end
  end

  it "should handle :gem value to unveil gems" do
    run_unveil("$stderr.reopen('/dev/null', 'w'); require 'rubygems'; gem 'minitest'; require 'minitest'; Pledge.unveil({}); require 'minitest/benchmark' rescue exit(1)").must_equal false
    run_unveil("require 'rubygems'; gem 'minitest'; require 'minitest'; Pledge.unveil('minitest'=>:gem, '.'=>'r'); require 'minitest/benchmark' rescue (p $!; puts $!.backtrace; exit(1))").must_equal true

    run_unveil("Pledge.unveil('gadzooks!!!'=>:gem) rescue exit(1)").must_equal false
  end

  it "should need create and write access for writing new files, and create access for removing files" do
    unveiled({'.'=>'w'}, "File.open(#{test_file.inspect}, 'w'){|f| f.write '1'} rescue exit(1)").must_equal false
    File.file?(test_file).must_equal false
    unveiled({'.'=>'c'}, "File.open(#{test_file.inspect}, 'w'){|f| f.write '1'} rescue exit(1)").must_equal false
    File.file?(test_file).must_equal false
    unveiled({'.'=>'cw'}, "File.open(#{test_file.inspect}, 'w'){|f| f.write '1'}").must_equal true
    File.read(test_file).must_equal '1'

    unveiled({'.'=>'w'}, "File.delete(#{test_file.inspect}) rescue exit(1)").must_equal false
    File.read(test_file).must_equal '1'
    unveiled({'.'=>'c'}, "File.delete(#{test_file.inspect})").must_equal true
    File.file?(test_file).must_equal false
  end
end if Pledge.respond_to?(:_unveil, true)
