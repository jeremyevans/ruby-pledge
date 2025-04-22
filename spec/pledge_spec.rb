require_relative 'unveil_spec'

describe "Pledge.pledge" do
  def execpledged(promises, execpromises, code)
    system(RUBY, '--disable-gems', '-I', 'lib', '-r', 'pledge', '-e', "Pledge.pledge(#{promises.inspect}, #{execpromises.inspect}); #{code}")
  end

  def _pledged(status, promises, code)
    system(RUBY, '--disable-gems', '-I', 'lib', '-r', 'pledge', '-e', "Pledge.pledge(#{promises.inspect}); #{code}").must_equal status
  end

  def pledged(code, promises="")
    _pledged(true, promises, code)
  end

  def unpledged(code, promises="")
    _pledged(false, promises, code)
  end

  def with_lib(*libs)
    rubyopt = ENV['RUBYOPT']
    ENV['RUBYOPT'] = "#{rubyopt} #{libs.map{|lib| "-r#{lib}"}.join(' ')}"
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
      unpledged("Addrinfo.getaddrinfo('google.com', nil)")
      pledged("Addrinfo.getaddrinfo('google.com', nil)", "dns")
    end
  end

  it "should allow internet access if inet is used" do
    with_lib('rubygems', 'net/http') do
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
