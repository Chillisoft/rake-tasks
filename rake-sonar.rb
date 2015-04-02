require "albacore"
require "runcommandwithfail"
require "rake-settings"

class Sonar
    include Albacore::Task
    include RunCommandWithFail

    def execute
        @command = $sonar_runner
        run_command("Sonar")
    end
end

desc "Runs sonar"
sonar :sonar do
  puts cyan("Running Sonar")
end
