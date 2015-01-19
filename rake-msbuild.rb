require "albacore"
require "rake-support"
require "rake-settings"

class Msbuild < MSBuild
    include Albacore::Task

    def execute
        if !$msbuild_exe.empty?
            @command = $msbuild_exe
        end
        puts green("Using msbuild at: " + @command)
        super()
    end
end
