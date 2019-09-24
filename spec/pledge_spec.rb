require './lib/pledge'

require 'rubygems'
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
gem 'minitest'
require 'minitest/global_expectations/autorun'

RUBY = ENV['RUBY'] || 'ruby'

describe "Pledge.pledge" do
  def execpledged(promises, execpromises, code)
    system(RUBY, '-I', 'lib', '-r', 'pledge', '-e', "Pledge.pledge(#{promises.inspect}, #{execpromises.inspect}); #{code}")
  end

  def _pledged(status, promises, code)
    system(RUBY, '-I', 'lib', '-r', 'pledge', '-e', "Pledge.pledge(#{promises.inspect}); #{code}").must_equal status
  end

  def pledged(code, promises="")
    _pledged(true, promises, code)
  end

  def unpledged(code, promises="")
    _pledged(false, promises, code)
  end

  def with_lib(lib)
    rubyopt = ENV['RUBYOPT']
    ENV['RUBYOPT'] = "#{rubyopt} -r#{lib}"
    yield
  ensure
    ENV['RUBYOPT'] = rubyopt
  end

  after do
    Dir['spec/_*'].each{|f| File.delete(f)}
    Dir['*.core'].each{|f| File.delete(f)}
  end

  it "should raise a Pledge::InvalidPromise for unsupported promises" do
    proc{Pledge.pledge("foo")}.must_raise Pledge::InvalidPromise
  end

  it "should raise a Pledge::PermissionIncreaseAttempt if attempting to increase permissions" do
    pledged("begin; Pledge.pledge('rpath'); rescue Pledge::PermissionIncreaseAttempt; exit 0; end; exit 1")
  end

  it "should produce a core file on failure" do
    unpledged("File.read('#{__FILE__}')")
    Dir['*.core'].wont_equal []
  end

  it "should allow reading files if rpath is used" do
    unpledged("File.read('#{__FILE__}')")
    pledged("File.read('#{__FILE__}')", "rpath")
  end

  it "should allow creating files if cpath and wpath are used" do
    unpledged("File.open('spec/_test', 'w'){}")
    unpledged("File.open('spec/_test', 'w'){}", "cpath")
    unpledged("File.open('spec/_test', 'w'){}", "wpath")
    File.file?('spec/_test').must_equal false
    pledged("File.open('#{'spec/_test'}', 'w'){}", "cpath wpath")
    File.file?('spec/_test').must_equal true
  end

  it "should allow writing to files if wpath and rpath are used" do
    File.open('spec/_test', 'w'){}
    unpledged("File.open('spec/_test', 'r+'){}")
    pledged("File.open('#{'spec/_test'}', 'r+'){|f| f.write '1'}", "wpath rpath")
    File.read('spec/_test').must_equal '1'
  end

  it "should allow dns lookups if dns is used" do
    with_lib('socket') do
      unpledged("Socket.gethostbyname('google.com')")
      pledged("Socket.gethostbyname('google.com')", "dns")
    end
  end

  it "should allow internet access if inet is used" do
    with_lib('net/http') do
      unpledged("Net::HTTP.get('127.0.0.1', '/index.html') rescue nil")
      promises = "inet"
      # rpath necessary on ruby < 2.1, as it calls stat
      promises << " rpath" if RUBY_VERSION < '2.1'
      pledged("Net::HTTP.get('127.0.0.1', '/index.html') rescue nil", promises)
    end
  end

  it "should allow killing programs if proc is used" do
    unpledged("Process.kill(:URG, #{$$})")
    pledged("Process.kill(:URG, #{$$})", "proc")
  end

  it "should allow creating temp files if tmppath and rpath are used" do
    with_lib('tempfile') do
      unpledged("Tempfile.new('foo')")
      unpledged("Tempfile.new('foo')", "tmppath")
      unpledged("Tempfile.new('foo')", "rpath")
      promises = "tmppath rpath"
      # cpath necessary on ruby < 2.0, as it calls mkdir
      promises << " cpath" if RUBY_VERSION < '2.0'
      pledged("Tempfile.new('foo')", promises)
    end
  end

  it "should allow unix sockets if unix and rpath is used" do
    require 'socket'
    us = UNIXServer.new('spec/_sock')
    with_lib('socket') do
      unpledged("UNIXSocket.new('spec/_sock').send('u', 0)")
      pledged("UNIXSocket.new('spec/_sock').send('t', 0)", "unix")
    end
    us.accept.read.must_equal 't'
  end

  it "should raise ArgumentError if given in invalid number of arguments" do
    proc{Pledge.pledge()}.must_raise ArgumentError
    proc{Pledge.pledge("", "", "")}.must_raise ArgumentError
  end

  it "should handle both promises and execpromises arguments" do
    execpledged("proc exec rpath", "stdio rpath", "exit(`cat MIT-LICENSE` == File.read('MIT-LICENSE'))").must_equal true
    execpledged("proc exec", "stdio rpath", "$stderr.reopen('/dev/null', 'w'); exit(`cat MIT-LICENSE` == File.read('MIT-LICENSE'))").must_equal false
    execpledged("proc exec rpath", "stdio", "$stderr.reopen('/dev/null', 'w'); exit(`cat MIT-LICENSE` == File.read('MIT-LICENSE'))").must_equal false
  end

  it "should handle nil arguments" do
    Pledge.pledge(nil).must_be_nil
    Pledge.pledge(nil, nil).must_be_nil
    execpledged("proc exec rpath", nil, "`cat MIT-LICENSE`").must_equal true
    execpledged("", nil, "`cat MIT-LICENSE`").must_equal false
    execpledged(nil, "stdio rpath", "`cat MIT-LICENSE`").must_equal true
    execpledged(nil, "stdio", "File.read('MIT-LICENSE')").must_equal true
    execpledged(nil, "stdio", "$stderr.reopen('/dev/null', 'w'); exit(`cat MIT-LICENSE` == File.read('MIT-LICENSE'))").must_equal false
  end
end

describe "Pledge.unveil" do
  def unveiled(unveils, code)
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil(#{unveils.inspect}); #{code}")
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
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil_without_lock({'.'=>'r'}); Pledge.unveil({}); #{test_read}").must_equal true
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil('foo/bar'=>'r') rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.send(:_unveil, '.', 'f') rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil({1=>'s'}) rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil({'s'=>1}) rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.send(:_unveil, 1, 'r') rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.send(:_unveil, '.', 1) rescue exit(1)").must_equal false
  end

  it "should handle require after unveil with read access after removing from $LOADED_FEATURES" do
    [File.join('.', test_file), File.join(Dir.pwd, test_file)].each do |f|
      f = f.inspect
      system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', <<-END).must_equal true
        File.open(#{f}, 'w'){|f| f.write '1'}
        require #{f}
        Pledge.unveil('spec'=>'r')
        $LOADED_FEATURES.delete #{f}
        require #{f}
      END
    end
  end

  it "should handle :gem value to unveil gems" do
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "$stderr.reopen('/dev/null', 'w'); require 'rubygems'; gem 'minitest'; require 'minitest'; Pledge.unveil({}); require 'minitest/benchmark' rescue exit(1)").must_equal false
    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "require 'rubygems'; gem 'minitest'; require 'minitest'; Pledge.unveil('minitest'=>:gem); require 'minitest/benchmark' rescue (p $!; puts $!.backtrace; exit(1))").must_equal true

    system(RUBY, '-I', 'lib', '-r', 'unveil', '-e', "Pledge.unveil('gadzooks!!!'=>:gem) rescue exit(1)").must_equal false
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
