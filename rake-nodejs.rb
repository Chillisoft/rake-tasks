require "albacore"
require "runcommandwithfail"
require "rake-filesystem"
require "json"

class NodeJs
    include Albacore::Task
    include RunCommandWithFail

    attr_accessor :base
    attr_accessor :script
    attr_accessor :parameters

    def initialize
        @base = "."
        if FileSystem.FindExecutable("node") == nil
            puts red("Node.js not found! Please install Node.js")
        end
        super()
    end

    def execute
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

    # base location of the web project (also location of package.json)
    #   (default ".")
    attr_accessor :base

    # npm command to execute
    #   (default "update")
    attr_accessor :command

    # parameters to send to npm command
    #   (no default [])
    attr_accessor :parameters

    def initialize
        @base = "."
        @command = "update"
        if FileSystem.FindExecutable("npm") == nil
            puts red("NPM not found! Please install Node.js")
        end
        super()
    end
    
    def run command, *parameters
        npm_command = @command
        begin
            @command = "npm"
            @working_directory = @base

            params = [command]
            params << parameters unless parameters.nil? || parameters.length == 0

            run_command("npm", params)
        ensure
            @command = npm_command
        end
    end

    def update *parameters
        run "update", parameters
    end

    def install *parameters
        run "install", parameters
    end

    def require packages
        return if packages.nil? || packages.length == 0
        packageJson = File.join(@base, "package.json")
        json = File.read(packageJson)
        obj = JSON.parse(json)
        devDependencies = obj["devDependencies"]
        packages.each do |package, version|
            devDependencies[package] = version
        end
        devDependencies.keys.sort.each { |key| devDependencies[key] = devDependencies.delete key }
        File.write(packageJson, JSON.pretty_generate(obj))
        install
    end

    def execute
        install
        run @command, @parameters
    end
end
