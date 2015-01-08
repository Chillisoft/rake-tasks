require "rake"
require "albacore"
require "albacore/support/supportlinux"
require "rake-filesystem"
require "runcommandwithfail"

class UpdateNugetPackages
    include Albacore::Task
    include RunCommandWithFail

    attr_accessor :solution

    def execute
        nuget = File.join(File.dirname(__FILE__), "NuGet.exe")
        @command = File.expand_path(nuget)
        run_command("NuGet", "restore #{@solution}")
    end
end

class GetNugetPackages
    include Albacore::Task
    include Albacore::RunCommand
    include Rake::DSL

    attr_accessor   :NugetParameters,
                    :package_names,
                    :output_folder,
                    :SourceUrl,
                    :Version
    
    def execute
        @command = "NuGet.exe"
        @output_folder = "lib" if @output_folder.nil?
        check_required_field @package_names, "package_names"
        package_default_path = "installedNugetPackages"

        FileSystem.DeleteDirectory(package_default_path)

        @package_names.each do  |package|
            @@getversion = ""
            if @Version.kind_of?(String)
                puts cyan("Nuget version Requested: #{@Version}")
                @@getversion = "-Version #{@Version}"
            end
            @NugetParameters = "install #{package} #{@@getversion} -OutputDirectory #{package_default_path} -Source #{@SourceUrl} -NoCache"
            puts cyan("Retrieving package:  #{package} from Nuget server: #{@SourceUrl}")
            puts("nuget cmd: " + @NugetParameters)
            if (run_command("Retrieving package #{package} from NuGet server #{@SourceUrl}", @NugetParameters) != true)
                fail_with_message "Unable to retrieve NuGet package with commandline:\n" + @command + " " + @NugetParameters
            end
        end
        
        puts cyan("Moving dlls from packages into output folder (" + @output_folder + ")")
        FileSystem.EnsurePath @output_folder
        
        FileSystem.CopyDlls(package_default_path, @output_folder)
        FileSystem.CopyWithFilter(package_default_path, @output_folder, "*.bak")
        
        FileSystem.DeleteDirectory(package_default_path)
    end

    def check_required_field(field, fieldname)
        return true if !field.nil?
        raise "Chilli Nuget: required field '#{fieldname}' is not defined"
    end
end

class PushNugetPackagesOnline
    include Albacore::Task
    include Albacore::RunCommand
    include Rake::DSL

    attr_accessor   :OutputDirectory, 
                    :InputFileWithPath, 
                    :Nugetid, 
                    :Version, 
                    :Description,
                    :DependencyID,
                    :DependencyVersion,
                    :ApiKey,
                    :SourceUrl

    def execute
        @OutputDirectory = "deploy" if @OutputDirectory.nil?

        check_required_field @InputFileWithPath, "InputFileWithPath"
        check_required_field @Nugetid, "Nugetid"
        check_required_field @Version, "Version"
        check_required_field @Description, "Description"

        FileSystem.DeleteDirectory(@OutputDirectory)
        FileSystem.EnsurePath("#{@OutputDirectory}/Package/lib")
        if @InputFileWithPath.kind_of?(String)
            @InputFileWithPath = [@InputFileWithPath]
        end
        @InputFileWithPath.each do |f|
            FileSystem.CopyFiles(f, "#{@OutputDirectory}/Package/lib")
        end
        #FileSystem.CopyFiles("#{@InputFileWithPath}", "#{@OutputDirectory}/Package/lib")

        puts cyan("#{@Nugetid}")
        puts cyan("#{@Version}")
        puts cyan("Chillisoft")
        puts cyan("#{@Description}")
        puts cyan("#{@OutputDirectory}/Package")
        puts cyan("#{@Nugetid}.nuspec")

        nuspec do |nuspec|
            nuspec.id = @Nugetid
            nuspec.version = @Version
            nuspec.authors = "Chillisoft"
            nuspec.description = @Description
            nuspec.working_directory = "#{@OutputDirectory}/Package"
            nuspec.output_file = "#{@Nugetid}.nuspec"
            if !@DependencyID.nil?
                @DependencyID.zip(@DependencyVersion).each do |id, version|
                    nuspec.dependency  id, version
                end
            end
        end

        nugetpack do |nugetpack|
            nugetpack.nuspec = "#{@OutputDirectory}/Package/#{@Nugetid}.nuspec"
            nugetpack.base_folder = "#{@OutputDirectory}/Package"
            nugetpack.output = "#{@OutputDirectory}"
        end

        nugetpush do |nugetpush|
            puts cyan("Pushing to Online Nuget Feed")
            nugetpush.package = FileSystem.winpath("#{@OutputDirectory}/#{@Nugetid}.#{@Version}.nupkg")
            nugetpush.apikey = "#{@ApiKey}"
            nugetpush.source = "#{@SourceUrl}"
        end

        puts cyan("Create the nuspec")
        Rake::Task[:nuspec].execute
        Rake::Task[:nuspec].clear

        puts cyan("Create the nuget package")
        Rake::Task[:nugetpack].execute
        Rake::Task[:nugetpack].clear

        puts cyan("Push the nuget package")
        Rake::Task[:nugetpush].execute
        Rake::Task[:nugetpush].clear

        FileSystem.DeleteDirectory(@OutputDirectory)
        sleep 0.5 # pause for 0.5 seconds
    end

    def check_required_field(field, fieldname)
        return true if !field.nil?
        raise "Chilli Nuget: required field '#{fieldname}' is not defined"
    end
end
