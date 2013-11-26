require 'rake'
require 'albacore'
require 'albacore/albacoretask'
require 'albacore/support/supportlinux'
require 'rake-filesystem.rb'

# Rake task type to create packages from your application
# What you need to use this:
# 1) make sure you have a "clean" folder with just the stuff you want to package in it
#     ideally, this is all of the binaries required to run your package and config IIF this is v1
# 2) set up a task to run like so:
# chillipackager :create_package |packager|
#   packager.EntryPoint = <path to your main .exe file>
#   packager.PackageVersionFile = <path to a text file containing the version of your app>
#   packager.Name = <name of your package, can be grokked from the entry-point (produces a warning)>
#   packager.Type = <type of package (one of "program", "service", "data", "hosted"); defaults to "program" with a warning>
#   packager.PackageLocation = <path to output folder for package>
# end
class ChilliPackager
	include Albacore::Task
	include Albacore::RunCommand
  include Rake::DSL

  attr_accessor :PackagerCmdPath # override location for PackagerCmd.exe; if not specified, it should be found for you
  attr_accessor :PackageVersionFile # specify package version in a text file instead of your rake file (just the integer version in this file please!)
  attr_accessor :PackageLocation # folder to put your package into
  attr_accessor :Version # specify version for this package. Rather use PackageVersionFile!
  attr_accessor :Name # set the name for this package (defaults to the base name of your entry point, with a warning)
  attr_accessor :EntryPoint # required for most package types: this defines for example the main .exe in your project
  attr_accessor :Type # type of package to create: one of program, data, service, hosted (for now at least)
                      # types explanations:
                      # program packages are a collection of files required to run a program with an entry 
                      # point being the main program
                      # service packages are like program packages except the entry point is registered as a 
                      # service and service control is handled for you
                      #         hosted packages are simply kept in the package cache. It's assumed that a 
                      #         local package server will pick this up and update via ChilliUpdate. 
                      #         Hosted packages send a signal via the GIPC library (often named-pipes) so
                      #         that the client can inform the user of an upgrade -- at which point the 
                      #         user should restart the client and get a free, gnarly upgrade
                      # data packages are just a collection of stuff to be deployed. They will become quite 
                      #         useful in the future.
  attr_accessor :Actions # actions to add to the package. This is work in progress. Documentation will be updated
  attr_accessor :CheckDependencies # rudimentary dependency checking to ensure that your package is complete. 
                                   # Note, however, that this functionality isn't perfect: if your project depends
                                   # on any of the libraries PackagerCmd uses, these will not be noticed as missing.
  attr_accessor :HostedPackageSignalIdentifier # override the signal identifier for hosted packages
  attr_accessor :OptionalFiles  # optional files are marked such and the client should only unpack them if they 
                                # don't exist already (useful for config files, for example). This may or may 
                                # not be supported by ChilliUpdate so check before you rely on it.
  attr_accessor :SourceFolder # if your executable isn't in the root of your source folder, you can set the source here
  attr_accessor :Exclude # string or list of string with file names or glob matches to exclude from the packing process
  attr_accessor :RawPackagerCmdOptions # if an option is missing, add it here (power users only)
  attr_accessor :RelativeTo # create package relative to a folder or another single package

  def execute
    check_required_field(@PackageLocation, "PackageLocation")
    FileSystem.EnsurePath(@PackageLocation)
    if !Dir.exist?(@PackageLocation)
      raise "Unable to ensure existence of release location: #{@PackageLocation}"
    end
    if @PackagerCmdPath.nil?
      if findPackagerCmd
          puts "found PackagerCmd.exe at: " + @PackagerCmdPath
      end
    end
    base = File.dirname(__FILE__)
    check_required_field(@PackagerCmdPath, "PackagerCmdPath", " (and not found when trawling upward from #{base} looking for a CSPackager folder")
    check_version() 
    check_required_field(@EntryPoint, "EntryPoint")
    if !File.exist?(@EntryPoint)
      raise "Unable to find EntryPoint at #{@EntryPoint} (pwd: " + Dir.pwd + ")"
    end
    check_package_name()
    check_package_type()
    if File.dirname(@EntryPoint).downcase() == @PackageLocation.downcase()
      raise "Package source and destination dirs cannot be the same as multiple runs will end up packaging packages from prior packaging packs (if you're confused, just make sure that you have a separate folder for the package to output to...)"
    end
    buildParameters()
    if !system(@PackagerCmdPath + " " + @parameters.join(" "))
    #if !run_command("Creating package \"#{@Name}\" version #{@Version}", @parameters.join(" ").gsub("/", "\\"))
      raise "Unable to create package with command:\n#{@PackagerCmdPath} " + @parameters.join(" ")
    end
  end

  def findPackagerCmd
      base = File.dirname(__FILE__)
      while !base.nil?
        search = File.join(base, "CSPackager", "PackagerCmd.exe")
        if File.exist?(search)
          @PackagerCmdPath = search
          return @PackagerCmdPath
        end
        base = base.slice(0, base.rindex(File::SEPARATOR))
      end
      return nil
  end

  def buildParameters()
    @parameters = []
    add_parameter(@Name, "-p")
    add_parameter(@Version, "-v")
    add_parameter(@EntryPoint, "-e")
    add_parameter(@PackageLocation, "-d")
    add_parameter(@Actions, "-a")
    add_parameter(@CheckDependencies, "-c")
    add_parameter(@OptionalFiles, "-o")
    add_parameter(@SourceFolder, "-s")
    add_parameter(@Exclude, "-x")
    add_parameter(@Type, "-t")
    add_parameter(@RelativeTo, "-r")
    

    if !@HostedPackageSignalIdentifier.nil?
      if @Type != "hosted"
        raise "HostedPackageSignalIdentifier can only be set for packages of the type \"hosted\""
      end
      parameters.push("-z").push(@HostedPackageSignalIdentifier)
    end

    if !@RawPackagerCmdOptions.nil?
      parameters.push(@RawPackagerCmdOptions)
    end
  end

  def add_parameter(var, switch)
    if !var.nil?
      @parameters.push(switch)
      if var.kind_of?Integer
        @parameters.push(String(var))
      elsif var.kind_of?String
        @parameters.push(var)
      elsif var.kind_of?Array
        for sub in var
          @parameters.push(String(var))
        end
      else
        raise "Unable to process parameter with type: " + var.class
      end
    end
  end

  def quote(str)
    if str.index(" ").nil?
      str = "\"#{str}\""
    end
    return str
  end

  def check_package_type()
    if @Type.nil?
      puts red("WARNING: package type not set: defaulting to program")
      @Type = "program"
    end
  end

  def check_package_name()
    if @Name.nil?
      @Name = File.basename(@EntryPoint).chomp(File.extname(@EntryPoint))
      puts red("WARNING: package name not set: defaulting to #{@Name}")
    end
  end

  def check_version()
    if @Version.nil?
      if @PackageVersionFile.nil?
        raise "Version not set and PackageVersionFile not set"
      end
      begin
        @Version = Integer(File.read(@PackageVersionFile).chomp().chomp(" "))
      rescue
        raise "Unable to grok version from #{@PackageVersionFile} (check that this file only contains an integer value)"
      end
    end
  end

  def check_required_field(field, fieldname, msg = nil)
    return if !field.nil?
    if msg.nil?
      raise "ChilliPackager: required field #{fieldname} not set"
    else
      raise "ChilliPackager: required field #{fieldname} not set #{msg}"
    end
  end
end
