require "albacore"
require "runcommandwithfail"

class Sonar
    include Albacore::Task
    include RunCommandWithFail

    def execute()
        @command = $sonar_runner_path
        run_command("Sonar")
    end
end

desc "Runs sonar"
sonar :sonar do
  puts cyan("Running Sonar")
end
