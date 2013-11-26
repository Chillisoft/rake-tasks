require 'rake'
require 'albacore'
require 'win32ole'
require 'albacore/albacoretask'
require 'albacore/support/supportlinux'
require 'rake-filesystem.rb'

class InnoSetup
  include Albacore::Task
  include Rake::DSL

  attr_accessor :ScriptFile
  attr_accessor :OutputFileBaseName
  attr_accessor :OutputFolder
  attr_accessor :Defines
  attr_accessor :ISCCBinary

  def execute()
    check_parameters()
    cmd = build_commandline()
    puts "InnoSetup command: " + cmd
    system(cmd)
  end

  def build_commandline()
    cmd = [@ISCCBinary, @ScriptFile]
    @Defines.keys.each do |k|
      cmd.push("/d" + k + "=" + @Defines[k])
    end
    if not @OutputFolder.nil?
      cmd.push("/o" + @OutputFolder)
    end
    return "\"" + cmd.join("\" \"") + "\"";
  end

  def check_parameters()
    if @ScriptFile.nil?
      fail "InnoSetup task: ScriptFile not set"
    end
    if not File.exist?(@ScriptFile)
      fail "InnoSetup task: Unable to find setup script at \"" + @ScriptFilePaht + "\" (did you perhaps forget to check it in?)"
    end
    if not @OutputFileBaseName.nil?
      if @OutputFileBaseName.length < 5
        puts red("InnoSetup task: WARNING: OutputFileBaseName set to something quite short: \"" + @OutputFileBaseName + "\"; using anyway, as requested")
      end
    end
    if not @OutputFolder.nil?
      if File.exist?(@OutputFolder) and not File.directory?(@OutputFolder)
        fail "InnoSetup task: \"" + @OutputFolder + "\" exists but is not a folder... bailing out"
      end
    end
    if @ISCCBinary.nil?
      @ISCCBinary = find_iscc()
    elsif not File.file?(@ISCCBinary)
      puts "InnoSetup task: specified ISCC binary not found (" + @ISCCBinary + "), searching..."
      @ISCCBinary = find_iscc()
    end
    if @Defines.nil?
      @Defines = {}
    end
    if not @Defines.instance_of?(Hash)
      fail "Defines must be a Hash (or nil). Use syntax like:\nsetup.Defines = {key=\"value\"}"
    end
  end

  def find_iscc()
    # look in search path
    `set`.split("\n").each do |line|
      if line =~ /(\w+)=(.+)/
        var = $1
        val = $2
        if var.downcase() == "path"
          val.split(";").each do |search|
            check = File.join(search.gsub("\\", File::SEPARATOR), "iscc.exe")
            if File.exist?(check)
              puts "InnoSetup task: using ISCC binary in my path at \"" + check + "\""
              return check
            end
          end
        end
      end
    end
    # look in expected installation folders
    file_system = WIN32OLE.new("Scripting.FileSystemObject")
    file_system.Drives.each do |drive|
      ["Program Files", "Program Files (x86)"].each do |search|
        check = File.join(drive.DriveLetter + ":", search, "Inno Setup 5", "ISCC.exe")
        if File.file?(check)
          puts "InnoSetup task: using ISCC from expected install location at: \"" + check + "\""
          return check
        end
      end
    end
    # give up
    fail "InnoSetup task: Unable to find ISCC.exe. Please install InnoSetup to the default location or ensure that ISCC.exe is in the path. Look at http://www.jrsoftware.org/isdl.php (I suggest getting the QuickStart pack and installing everything (you NEED preprocessor, the rest is optional)"
  end

end
