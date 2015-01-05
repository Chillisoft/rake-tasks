require "albacore"
require "runcommandwithfail"
require "rake-filesystem"

class NodeJs
    include Albacore::Task
    include RunCommandWithFail

    attr_accessor :base
    attr_accessor :script
    attr_accessor :parameters

    def initialize()
        @base = "."
        if FileSystem.FindExecutable("node") == nil
            puts red("Node.js not found! Please install Node.js")
        end
        super()
    end

    def execute()
        @command = "node"
        @working_directory = @base

        params = [@script]
        params << @parameters unless @parameters.nil? || @parameters.length == 0

        run_command("Node.js", params)
    end
end

class Npm
    include Albacore::Task
    include RunCommandWithFail

    attr_accessor :base

    def initialize()
        @base = "."
        if FileSystem.FindExecutable("npm") == nil
            puts red("NPM not found! Please install Node.js")
        end
        super()
    end

    def execute()
        @command = "npm"
        @working_directory = @base

        params = ["install"]
        run_command("npm", params)
    end
end
