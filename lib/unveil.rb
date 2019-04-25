# frozen-string-literal: true

require 'pledge'
raise LoadError, "unveil not supported" unless Pledge.respond_to?(:_unveil, true)

module Pledge
  # Limit access to the file system using unveil(2).  +paths+ should be a hash
  # where keys are paths and values are the access permissions for that path.  Each
  # value should be a string with the following characters specifying what
  # permissions are allowed:
  #
  # r :: Allow read access to existing files and directories
  # w :: Allow write access to existing files and directories
  # c :: Allow create/delete access for new files and directories
  # x :: Allow execute access to programs
  #
  # You can use the empty string as permissions if you want to allow no access
  # to the given path, even if you have granted some access to a folder above
  # the given folder.  You can use a value of +:gem+ to allow read access to
  # the directory for the gem specified by the key.
  #
  # If called with an empty hash, adds an unveil of +/+ with no permissions,
  # which denies all access to the file system if +unveil_without_lock+
  # was not called previously.
  def unveil(paths)
    if paths.empty?
      paths = {'/'=>''}
    end

    unveil_without_lock(paths)
    _finalize_unveil!
  end

  # Same as unveil, but allows for future calls to unveil or unveil_without_lock.
  def unveil_without_lock(paths)
    paths = Hash[paths]

    paths.to_a.each do |path, perm|
      unless path.is_a?(String)
        raise UnveilError, "unveil path is not a string: #{path.inspect}"
      end

      case perm
      when :gem
        unless spec = Gem.loaded_specs[path]
          raise UnveilError, "cannot unveil gem #{path} as it is not loaded"
        end

        paths.delete(path)
        paths[spec.full_gem_path] = 'r'
      when String
        # nothing to do
      else
        raise UnveilError, "unveil permission is not a string: #{perm.inspect}"
      end
    end

    paths.each do |path, perm|
      _unveil(path, perm)
    end

    nil
  end
end
