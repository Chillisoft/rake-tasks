require "albacore"
require "runcommandwithfail"

class Powershell
    include Albacore::Task
    include Albacore::RunCommand

    # PowerShell script to execute
    #   (no default)
    attr_accessor :script

    # list of parameters to pass to the script
    #   (no default)
    attr_accessor :parameters

    def execute
        @command = "powershell"

        params = [
            "-NoProfile",
            "-ExecutionPolicy Bypass"
        ]
        params << "-File \"#{@script}\"" if @script

        # run_command passes params first, then also adds @parameters
        run_command("PowerShell", params)
    end
end
