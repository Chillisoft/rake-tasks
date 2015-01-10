require "albacore"
require "fileutils"
require "runcommandwithfail"
require "rake-settings"

class Dotcover
    include Albacore::Task
    include RunCommandWithFail

    attr_accessor :assemblies
    attr_accessor :filters
    attr_accessor :nunitoptions

    # location where lint results will be stored (relative to base)
    #   (default "buildreports/")
    attr_accessor :reports

    def initialize
        @reports = "buildreports"
        super()
    end

    def assemblies(ass)
        @assemblies = ass
    end

    def filters(f)
        @filters = f
    end

    def nunitoptions(opt)
        @nunitoptions = opt
    end

    def execute
        @command = $dotcover_console
        ass = @assemblies.collect { |a| File.expand_path(a) }.join(" ")
        result_xml = File.expand_path(File.join(@reports, "nunit-result.xml"))
        nunit_options = "\"#{ass} /xml=#{result_xml}"
        nunit_options << " #{@nunitoptions}" if !@nunitoptions.nil? && @nunitoptions.length > 0
        nunit_options << "\""
        coveragesnapshotfile = File.expand_path(File.join(@reports, "coveragesnapshot"))
        coveragebasename = File.expand_path(File.join(@reports, "coverage"))

        run_command "dotcover console coverage analysis", "cover /TargetExecutable=\"#{$nunit_console}\" /AnalyseTargetArguments=false /TargetArguments=#{nunit_options} /Output=\"#{coveragesnapshotfile}\" /Filters=#{@filters} "
        run_command "dotcover console coverage report (xml)", "report /ReportType=XML /Source=\"#{coveragesnapshotfile}\" /Output=\"#{coveragebasename}.xml\""
        run_command "dotcover console coverage report (html)", "report /ReportType=HTML /Source=\"#{coveragesnapshotfile}\" /Output=\"#{coveragebasename}.html\""

        FileUtils.rm coveragesnapshotfile
    end
end
