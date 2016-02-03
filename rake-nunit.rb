require "albacore"
require "fileutils"
require "rake-settings"

class NUnit < NUnitTestRunner
    include Albacore::Task

    # location where nunit results will be stored (relative to base)
    #   (default "buildreports/")
    attr_accessor :reports

    def initialize(command = nil)
        @reports = "buildreports"
        super()
    end

    def execute
        @command = $nunit_console
        buildreports = File.expand_path(@reports)
        FileUtils.mkdir_p buildreports
        result_xml = File.join(buildreports, "nunit-result.xml")
        if $nunit_console =~ /nunit.org/i
            @options << "--x86" << "--result=#{result_xml};format=nunit2"
        else
            @options << "/xml=#{result_xml}" << "/noshadow"
        end
        super()
    end
end
