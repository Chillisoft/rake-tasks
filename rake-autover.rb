require 'rake'
require 'albacore'
require 'albacore/albacoretask'
require 'albacore/support/supportlinux'
require 'rake-filesystem.rb'

# to use, make :msbuild depend on :autoUpdateVersions, like so:
# task :msbuild => [:autoUpdateVersions]
#
# if you just want file versions, that's all you need (and, of course, to link that into your build task). For more
# configuration, check out the class comments below
#
#
# TODO: genericise this for other VCS usages (eg, git)

class AutoVersion
  include Albacore::Task
  include Rake::DSL

  attr_accessor :TrunkMajor # int: defaults to 9, use something else to automatically set version when in trunk
  attr_accessor :TrunkMinor # like above but for the minor version
  attr_accessor :TrunkRevision # like above but for revision
  attr_accessor :GetVersionFromBranch # boolean: if true (default), attempt to get major.minor from branch
  attr_accessor :Projects # list (or one) project to work with; defaults to *, which sets version info for all projects
                          #   in the solution
  attr_accessor :VersionInfoFileNames # defaults to AssemblyInfo.cs; override if you're doing something special, can be a single string or array of strings
  attr_accessor :SetAssemblyVersions # boolean switch, defaults to true
  attr_accessor :SetFileVersions # boolean switch, defaults to true
  attr_accessor :WorkingCopy # path, defaults to "."
  attr_accessor :KeepVersionInfoChanges # don't revert changes when finished (this may interfere with vcs processes
                                        # at the build server eg if your build job uses svn update instead of 
                                        # new checkout
                                        # however, you may choose to keep changes from a specific task to get nice
                                        # version numbers with your local builds (this defaults to true)
  attr_accessor :AddVersionInfoIfMissing # add version info structures if they are missing (default true): if the
                                          # version info files are missing the version attributes, they will be added
                                          # for you unless you set this off
  attr_accessor :MaxValueForVersionNumber # set max that can be used in a version number part (defaults to 32000 which is quite safe) 
  attr_accessor :ReplaceTokens # list of lists defining where and how to replace tokens in source files with 
                               #  version numbers with the following directives:
                               #  [filename, token, version_digits]
  #  with the following meanings:
  #  filename: name of file to search for token
  #  token:    token to search for. Your token should appear in your source as $(token)
  #  version_digits: (optional, defaults to all 4) how many digits to use in the replacement (1 to 4)
  attr_accessor :VCS # type of VCS to use against this code (you may set this to 'none' to disable any VCS magic, at
                      # your own peril

  attr_accessor :infofiles
  attr_accessor :sourcefiles

  def execute
    set_defaults()
    lastrev = -2
    buildnumber = 0
    determine_vcs()
    puts yellow("Using vcs logic for: " + @VCS)
    do_vcs_maintenance()
    buildnumber = get_buildnumber(@WorkingCopy)
    if buildnumber < 0
      raise "Unable to determine buildnumber for source under " + Dir.pwd
    end
    msg = ""
    if @SetAssemblyVersions
      msg = "Setting assembly version(s)"
    end
    if @SetFileVersions
      if msg != ""
        msg += " and "
      else
        msg = "Setting "
      end
      msg += "file version(s)"
    end

    $VERSION_MAJOR, $VERSION_MINOR, $VERSION_REVISION, $VERSION_BUILD = determine_version_numbers(buildnumber)
    
    puts "#{msg} to : #{$VERSION_MAJOR}.#{$VERSION_MINOR}.#{$VERSION_REVISION}.#{$VERSION_BUILD}"

    @infofiles = modify_assembly_infos(@Projects, $VERSION_MAJOR, $VERSION_MINOR, $VERSION_REVISION, $VERSION_BUILD)
    @sourcefiles = modify_tokenised_sourcefiles(@Projects, $VERSION_MAJOR, $VERSION_MINOR, $VERSION_REVISION, $VERSION_BUILD)
    
    if !@KeepVersionInfoChanges
      Kernel.trap("EXIT") do
        # WARNING!!!
        # (REALLY, READ THIS BEFORE ATTEMPTING ANYTHING HERE)
        # Code run from Kernel.trap cannot be traced and will, if it fails for ANY reason
        # (such as syntax error or typo on variable name at access time), cause the Rake
        # job to finish with a non-zero status AND NO FEEDBACK AS TO WHY. So don't touch this 
        # logic unless you're (a) brave and (b) prepared to zen debug (or your name is
        # John Carmack, in which case, you're free to do as you please)
        revert_modified_files()
      end
    end
  end

  def revert_modified_files()
    puts "Reverting modified files"
    revert_files(@sourcefiles)
    revert_files(@infofiles)
    if not @sourcefiles.nil? or not @infofiles.nil?
      puts "Reversions complete!"
    else
      puts " => nothing to do!"
      puts " (note: this may be a sign of an incomplete reversion from a prior run; alternatively, you need to set up the autoversioning for this job better)"
    end
  end

  def revert_files(listOfPaths)
    if listOfPaths.nil?
      return
    end
    toDelete = []
    listOfPaths.each do |file|
      puts cyan("  => " + file)
      d = revert_file(file)
      toDelete.push(revert_file(file))
    end
    toDelete.each do |file|
      begin
        File.delete(file)
      rescue
      end
    end
  end

  def revert_file(path)
    shadow = get_shadow_filename(path)
    begin
      FileUtils.cp(shadow, path)
    rescue
      puts red("WARNING: Unable to revert modified file \"" + file + "\"; you may experience issues next time you build")
    end
    return shadow
  end

  def svn_revert()
    if infofiles.length
      puts yellow("Reverting assembly info files...")
      cmd = "svn revert \"" + infofiles.join("\" \"") + "\""
      system(cmd)
    end
    if sourcefiles.length
      puts yellow("Reverting tokenised source files...")
      cmd = "svn revert \"" + sourcefiles.join("\" \"") + "\""
      system(cmd)
    end
    return 0
  end

  def get_buildnumber(path)
    case @VCS
      when "svn"
        return get_highest_rev_svn(path)
    end
    return 0
  end

  def do_vcs_maintenance()
    case @VCS
      when "svn"
        svn_upgrade(@WorkingCopy)
    end
  end

  def determine_vcs()
    # traverse up the source tree from this file and look for markers of vcs systems
    if @VCS != nil and @VCS.downcase == "none"
      @VCS = "none"
      return
    end
    node = __FILE__
    while File.exists?(node) and node != "."
      node = File.dirname(node)
      [".svn", "_svn"].each do |search|
        if File.directory?(File.join(node, search))
          @VCS = "svn"
          return
        end
      end
    end
  end

  def raise_with_pwd(msg)
    raise msg + " (pwd: " + Dir.pwd + ")"
  end

  def svn_upgrade(wcpath)
    # the 'svn info' command may require an upgrade on the working copy; this intermediatary batch process
    #   performs the upgrade without barfing if it can't be done (eg if it's unnecessary)
    fn = "__do_upgrade.bat"
    File.write(fn, "@svn upgrade \"#{wcpath}\" 2> nul\r\n@exit 0\r\n");
    begin
      system(fn)
    rescue
    end
    File.delete(fn)
  end

  def modify_tokenised_sourcefiles(projects, major, minor, revision, build)
    if @ReplaceTokens == nil
      return
    end
    modified_files = []
    for spec in @ReplaceTokens
      fpath = find_file(spec[0], projects)
      if fpath == nil
        raise_with_pwd "Unable to find #{f} in project space"
      end
      search = "$(#{spec[1]})"
      replace = get_token_replace_version(major, minor, revision, build, spec)
      lines = File.read(fpath).split("\n")
      newlines = []
      found = false
      for line in lines
        line = line.gsub("\r", "").gsub("\n", "")
        modded = line.gsub(search, replace)
        if modded != line
          newlines.push(modded)
          found = true
        else
          newlines.push(line)
        end
      end
      if not found
        puts red("WARNING: Unable to find token #{search} in source file #{fpath}")
      else
        File.write(fpath, newlines.join("\n"))
        modified_files.push(fpath)
      end
    end
    return modified_files
  end

  def get_token_replace_version(major, minor, revision, build, spec)
    if spec.length < 3
      spec.push(4)
    end
    digits = spec[2].to_i
    if digits < 1
      if spec[2].to_s != "0"
        raise "Invalid version_digits setting: #{spec[2]} (must be an integer)"
      else
        raise "version_digits must be > 0"
      end
    end
    src = [major, minor, revision, build]
    ver = []
    for i in 0..(digits-1)
      ver.push(src[i])
    end
    return ver.join(".")
  end

  def find_file(relpath, projects)
    tests = [File.join("source", relpath)]
    for p in projects
      tests.push(File.join("source", p, relpath))
    end
    for f in tests
      if File.exist?(test)
        return test
      end
    end
    return nil
  end

  def modify_assembly_infos(projects, major, minor, build, revision)
    asmverstart = "[assembly: AssemblyVersion"
    fileverstart = "[assembly: AssemblyFileVersion"
    modified_files = []
    for p in projects
      test = File.join("source", p)
      if Dir.exist?(test)
        p = test
      end
      if !Dir.exist?(p)
        raise_with_pwd "Unable to find project dir:" + p
      end
      foundAssemblyInfo = false
      @VersionInfoFileNames.each do |vinfoItem|
        if File.basename(p).downcase() == "common"
          asmfile = File.join(p, vinfoItem)
        else
          asmfile = File.join(p, "Properties", vinfoItem)
        end
        if !File.exists?(asmfile) 
          next
        end
        foundAssemblyInfo = true
        lines = File.read(asmfile).split("\n")
        done_asmver = false
        done_filever = false
        newlines = []
        for line in lines
          line = line.gsub("\r", "").gsub("\n", "")
          if line.length == 0
            next
          end
          if @SetAssemblyVersions && line.start_with?(asmverstart)
            if set_ver_if_required(p, newlines, "assembly", asmverstart, line, asmfile, major, minor, build, revision)
              done_asmver = true
              next
            end
          end
          if @SetFileVersions && line.start_with?(fileverstart)
            if set_ver_if_required(p, newlines, "file", fileverstart, line, asmfile, major, minor, build, revision)
              done_filever = true
              next
            end
          end
          newlines.push(line);
        end
        if !done_asmver && @SetAssemblyVersions && @AddVersionInfoIfMissing
          newlines.push(create_ver_line(asmverstart, mod_ver("", "1.0.0.0", major, minor, build, revision)))
        end
        if !done_filever && @SetFileVersions && @AddVersionInfoIfMissing
          newlines.push(create_ver_line(fileverstart, mod_ver("", "1.0.0.0", major, minor, build, revision)))
        end

        if done_asmver || done_filever
          FileUtils.cp(asmfile, get_shadow_filename(asmfile))
          puts yellow("Setting assembly version in: " + asmfile)
          File.write(asmfile, newlines.join("\n"))
          modified_files.push(asmfile)
        end
      end
      if !foundAssemblyInfo
        raise_with_pwd "Unable to find AssemblyInfo in \"" + File.join(p, "Properties") + "\"; searching for: " + @VersionInfoFileNames.join(",")
      end
    end
    return modified_files
  end

  def get_shadow_filename(path)
    return File.join(File.dirname(path), "." + File.basename(path) + ".rake-autover")
  end

  def set_ver_if_required(project, outlines, vertype, linestart, line, verfile, major, minor, build, revision)
    filever = grok_ver(line, linestart)
    if filever == ""
      raise "Unable to determine #{vertype} version from: #{verfile}"
    end
    modded_ver = mod_ver(verfile, filever, major, minor, build, revision)
    ret = (modded_ver != filever)
    if ret
      puts  "#{project}: modded #{vertype} version from: #{filever} to #{modded_ver}"
      outlines.push(create_ver_line(linestart, modded_ver))
    end
    return ret
  end
  def create_ver_line(startwith, ver)
    return startwith + "(\"" + ver + "\")]"
  end

  def mod_ver(asmfile, verString, major, minor, build, revision)
    parts = verString.split(".")
    if (parts.length > 4)
      raise "Invalid version: " + verString + " found in file: " + asmfile
    end
    while parts.length < 4
      parts.push("0")
    end
    modsrc = [major, minor, build, revision]
    for i in 0..3
      if modsrc[i] != "x"
        parts[i] = modsrc[i]
      end
    end
    return parts.join(".")
  end

  def grok_ver(line, startsWith)
    verString = line.gsub(startsWith, "")
    ret = ""
    for char in verString.split("")
      if "1234567890.".index(char) == nil
        if ret != ""
          #puts "grok_ver: ret == \"" + ret + "\""
          break
        end
        next
      end
      ret += char
    end
    return ret
  end

  def determine_version_numbers(rev)
    if @GetVersionFromBranch
      parts = Dir.pwd.split(File::SEPARATOR)
      next_is_version = false
      for part in parts
        if part == "branches"
          next_is_version = true
          next
        end
        if part == "trunk"
          major = @TrunkMajor
          minor = @TrunkMinor
          revision = @TrunkRevision
          break
        end
        if next_is_version
          ver = part.sub(/^v/, "")
          parts = ver.split(".")
          if parts.length > 3
            puts red("WARNING: only using the first three version numbers from: " + parts.join("."))
          end
          while parts.length < 3
            parts.push("0")
          end
          major = grok_int(parts[0])
          minor = grok_int(parts[1])
          revision = grok_int(parts[2])
          break
        end
      end
    else
      major = "x"
      minor = "x"
      revision = "x"
    end

    build = rev
    
    major = check_bounds(major, "major")
    minor = check_bounds(minor, "minor")
    revision = check_bounds(revision, "revision")
    build = check_bounds(build, "build")

    return major, minor, revision, build
  end

  def check_bounds(var, name)
    if var.instance_of?(Fixnum)
      if var > @MaxValueForVersionNumber
        puts red("WARNING: value for #{name} (#{var}) greater than max set (#{@MaxValueForVersionNumber}); modding by #{@MaxValueForVersionNumber} to save your build!")
        var %= @MaxValueForVersionNumber
      end
    end
    return var
  end

  def grok_int(str)
    ret = ""
    for char in str.split("")
      if "0123456789".index(char)
        ret += char
      else
        break
      end
    end
    if ret == ""
      return 0
    else
      return ret.to_i()
    end
  end

  def set_defaults()
    grok_projects()
    @SetAssemblyVersions = check_boolean(@SetAssemblyVersions, "SetAssemblyVersions", false)
    @SetFileVersions = check_boolean(@SetFileVersions, "SetFileVersions", true)
    @WorkingCopy = check_folder(@WorkingCopy, "WorkingCopy", ".")
    @VersionInfoFileNames = check_string_array(@VersionInfoFileNames, "VersionInfoFileNames", ["AssemblyInfo.cs", "AssemblyInfoShared.cs"])
    @GetVersionFromBranch = check_boolean(@GetVersionFromBranch, "GetVersionFromBranch", true)
    @TrunkMinor = check_int(@TrunkMinor, "TrunkMinor", 9)
    @TrunkMajor = check_int(@TrunkMajor, "TrunkMajor", 9)
    @TrunkRevision = check_int(@TrunkRevision, "TrunkRevision", 9)
    @KeepVersionInfoChanges = check_boolean(@KeepVersionInfoChanges, "KeepVersionInfoChanges", false)
    @MaxValueForVersionNumber = check_int(@MaxValueForVersionNumber, "MaxValueForVersionNumber", 32000)
    if @ReplaceTokens != nil
      if @ReplaceTokens.class != Array
        raise "ReplaceTokens must be an array"
      end
      for rt in @ReplaceTokens
        if rt.class != Array
          raise "ReplaceTokens elements must be arrays -- otherwise how will I know what to replace and where?!"
        end
        if rt.length < 2
          raise "ReplaceTokens elements must have at least two elements of their own: file and token"
        end
      end
    end
  end

  def check_string_array(var, name, defaultvalue)
    if (var.nil?)
      return defaultvalue
    end
    if var.instance_of?(String)
      return [var]
    end
    if !var.instance_of?(Array)
      raise "Invalid (non-string or non-array-of-string) value for " + name + ": " + var
    end
    var.each do |item|
      if !var.instance_of?(String)
        raise "Invalid (non-string) item value for " + name + ": " + item
      end
    end
    return var
  end

  def check_boolean(var, name, defaultvalue)
    if var.nil?
      return defaultvalue
    end
    if !var.instance_of?(TrueClass) && !var.instance_of?(FalseClass)
      raise "Invalid (non-boolean) value for " + name + ": " + var
    end
    return var
  end

  def check_int(var, name, defaultvalue)
    if var.nil?
      return defaultvalue
    end
    if !variable.instance_of?(Int)
      raise "Invalid (non-string) value for " + name + ": " + var
    end
    return variable
  end

  def check_string(var, name, defaultvalue)
    if var.nil?
      return defaultvalue
    end
    if !variable.instance_of?(String)
      raise "Invalid (non-string) value for " + name + ": " + var
    end
    return variable
  end

  def check_folder(var, name, defaultvalue)
    if var.nil?
      return defaultvalue
    end
    if !variable.instance_of?(String)
      raise "Invalid (non-string) value for " + name + ": " + var
    end
    if !Dir.exist?(var)
      raise "Unable to find folder: " + var + " (pwd: " + Dir.pwd + ")"
    end
    return var
  end

  def grok_projects()
    if @Projects.nil? || @Projects == "*"
      @Projects = []
      for sub in Dir.glob("source/*")
        if !Dir.exist?(sub)
          next
        end
        propDir = File.join(sub, "Properties")
        if !Dir.exist?(propDir)
          next
        end
        @Projects.push(sub)
      end
    elsif !@Projects.instance_of?(Array)
      @Projects = [@Projects]
      for p in @Projects
        test = File.join("source", p)
        if !Dir.exist?(test)
          raise "Unable to find project dir: " + test
        end
      end
    end
    commonFolder = File.join("source", "Common")
    if File.directory?(commonFolder)
      @Projects.push(commonFolder)
    end
  end

  def get_highest_rev_at_repo(wcpath)
    begin
      for line in `svn info -r HEAD "#{wcpath}"`.split("\n")
        line = line.chomp("\r").chomp()
        if line.start_with?("Revision:")
          parts = line.split(": ")
          if parts.length != 2
            raise "RUH-ROH: \"#{line}\" doesn't split into two parts? THE END OF THE WORLD IS NIGH AND THIS IS PROOF"
          end
          begin
            return parts[1].chomp().to_i()
          rescue
            raise "Can't grok an int out of: " + parts[1] + " from line: " + line
          end
        end
      end
      return 0
    rescue
      return -1
    end
  end

  def get_highest_rev_svn(wcpath)
    highest_rev = -1
    for line in `svn info "#{wcpath}" --depth infinity`.split("\n")
      parts = line.split(": ")
      if parts.length != 2
        next
      end
      if parts[0] == "Revision"
        begin
          test = parts[1].chomp("\n").chomp("\r").chomp().to_i()
          if test > highest_rev
            highest_rev = test
          end
        rescue
          puts "fooey"
        end
      end
    end
    return highest_rev
  end
end

desc "Update version info from svn info"
autoversion :autoUpdateVersions do |a|
end
