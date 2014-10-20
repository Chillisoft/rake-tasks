require "rake"
require "albacore"
require "rake-nodejs"

class Plato
    include Albacore::Task
    include Albacore::RunCommand
    include Rake::DSL

    # base location of the web project
    #   (default ".")
    attr_accessor :base

    # location where resulting html will be stored (relative to base)
    #   (default "buildreports/plato/")
    attr_accessor :reports

    # array of base location(s) of js source code to be linted
    #   (default ".")
    attr_accessor :source

    # array of file wildcards to exclude from processing (eg. ["lib/*", "plugin/*"])
    #   (default [])
    attr_accessor :exclude

    def initialize()
        @base = "."
        @reports = "buildreports/plato"

        $buildscripts = File.dirname(__FILE__)
        $plato = File.join($buildscripts, "node_modules/.bin", "plato.cmd")
        unless $plato.nil?
            $plato = File.expand_path($plato) if File.exists?($plato)
        end

        npm do |npm|
            npm.base = $buildscripts
        end
        Rake::Task[:npm].execute
        Rake::Task[:npm].clear

        super()
    end

    def execute()
        reports = File.expand_path(File.join(@base, @reports))
        FileSystem.EnsurePath(reports)

        source = @source
        source = "." if @source.nil? || @source.length == 0

        exclude = []
        exclude << @exclude unless @exclude.nil? || @exclude.length == 0

        @command = $plato
        @working_directory = @base
        params = []
        params << "-d" << "\"" + reports + "\""
        params << "-x" << "\"(#{exclude.join('|')})\"" if exclude.length > 0
        params << "-r" << source

        run_command("Plato", params)
    end
end
