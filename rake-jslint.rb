require "rake"
require "albacore"
require "rake-nodejs"
require "rexml/document"
require "rbconfig"
require "colorize"

if RbConfig::CONFIG['build'] =~ /mswin/i or RbConfig::CONFIG['build'] =~ /mingw32/i
    require "win32console"
end

class JSLint
    include Albacore::Task
    include Albacore::RunCommand
    include Rake::DSL

    # base location of the web project
    #   (default ".")
    attr_accessor :base

    # location where lint results will be stored (relative to base)
    #   (default "buildreports/")
    attr_accessor :reports

    # array of base location(s) of js source code to be linted
    #   (default ".")
    attr_accessor :source

    # true to run Checkstyle report, false to run jslint
    #   (default false)
    attr_accessor :checkstyle

    def initialize()
        @base = "."
        @reports = "buildreports"

        $buildscripts = File.dirname(__FILE__)
        $jshint = File.join($buildscripts, "node_modules/.bin", "jshint.cmd")
        unless $jshint.nil?
            $jshint = File.expand_path($jshint) if File.exists?($jshint)
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

        @command = $jshint
        @working_directory = @base
        params = ["--jslint-reporter"] unless @checkstyle
        params = ["--checkstyle-reporter"] if @checkstyle
        params << "--config" << "#{$buildscripts}/.jshintrc"
        params << source

        report = File.join(reports, "jslint.xml") unless @checkstyle
        report = File.join(reports, "checkstyle-jshint.xml") if @checkstyle
        FileSystem.CaptureOutput(report) do
            if run_command("JSHint", params) == nil
              fail_with_message "Unable to run command: #{@command} #{params}"
            end
        end
    end
end

class JSLintOutput
    include Albacore::Task

    # base location of the web project
    #   (default ".")
    attr_accessor :base

    # location where lint results can be found (relative to base)
    #   (default "buildreports/")
    attr_accessor :reports

    def initialize()
        @base = "."
        @reports = "buildreports"
        super()
    end

    def getColorForSeverity(severity)
        severityColors = {
            "error" => :red,
            "E" => :red,
            "warning" => :yellow,
            "W" => :yellow
        }
        if severityColors.keys.index(severity) == nil
            return :magenta
        end
        return severityColors[severity]
    end

    def getNodeSpec(doc)
        test = "/checkstyle"
        doc.elements.each(test) do |el|
            return test + "/file", "error", "column"
        end
        test = "/jslint"
        doc.elements.each(test) do |el|
            return test + "/file", "issue", "char"
        end
        raise "Can't determine node to look for ):"
    end

    def execute()
        reports = File.expand_path(File.join(@base, @reports))
        reportFilePath = File.join(reports, "jslint.xml") unless @checkstyle

        if not File.exists?(reportFilePath)
            puts red("Lint output to console reporter: Unable to find lint report at: %s " % [ reportFilePath ])
            return
        end

        doc = REXML::Document.new(File.new(reportFilePath))
        nodeSpec, subEl, colAttribute = getNodeSpec(doc)
        doc.elements.each(nodeSpec) do |fileElement|
            if not fileElement.has_elements?
                next
            end
            puts fileElement.attributes["name"].colorize("cyan")
            fileElement.elements.each(subEl) do |errorElement|
                color = getColorForSeverity(errorElement.attributes["severity"])
                col = errorElement.attributes[colAttribute]
                line = errorElement.attributes["line"]
                msg = errorElement.attributes["message"]
                if msg.nil?
                    msg = errorElement.attributes["reason"]
                end
                logLine = "  [%s:%s] %s" % [line, col, msg]
                puts logLine.colorize(color)
            end
        end
    end
end
