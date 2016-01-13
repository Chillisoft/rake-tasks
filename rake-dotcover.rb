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

    # true to cover each assembly separately and merge results, false to run all assemblies at same time
    #   (default false)
    # - this hopefully will prevent OutOfMemoryExceptions
    attr_accessor :partition

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
        coveragesnapshotfile = File.expand_path(File.join(@reports, "coveragesnapshot"))
        @assemblies = [@assemblies].flatten

        if @partition
            snapshots = @assemblies.each_with_index.map { |a,i|
                snapshot = coveragesnapshotfile + "-#{i}"
                puts cyan("Covering #{a}")
                cover [a], snapshot, "nunit-result-#{i}.xml"
                snapshot
            }
            merge snapshots, coveragesnapshotfile
            delete snapshots
        else
            cover @assemblies, coveragesnapshotfile, "nunit-result.xml"
        end

        reports coveragesnapshotfile
        delete coveragesnapshotfile
    end

    def cover(assemblies, coveragesnapshotfile, nunitresultfile)
        description = "dotCover console coverage analysis"
        ass = assemblies.map { |a| File.expand_path(a) }.join(" ")
        result_xml = File.expand_path(File.join(@reports, nunitresultfile))
        nunit_options = ["#{ass}"]
        if $nunit_console =~ /nunit.org/i
            nunit_options << ["--x86", "--result=#{result_xml};format=nunit2"]
        else
            nunit_options << ["/xml=#{result_xml}", "/noshadow"]
        end
        nunit_options << @nunitoptions
        cmdline = "cover /TargetExecutable=\"#{$nunit_console}\" /AnalyseTargetArguments=false /TargetArguments=\"#{nunit_options.join(' ')}\" /Output=\"#{coveragesnapshotfile}\" /Filters=#{[*@filters].join(';')}"
        run_command description, cmdline
    end

    def merge(snapshots, mastercoveragesnapshotfile)
        puts cyan("Merging coverage snapshots")
        description = "dotCover console merge snapshots"
        source = snapshots.join(";")
        cmdline = "merge /Source=\"#{source}\" /Output=\"#{mastercoveragesnapshotfile}\""
        run_command description, cmdline
    end

    def reports(mastercoveragesnapshotfile)
        description = "dotCover console coverage report"
        coveragebasename = File.expand_path(File.join(@reports, "coverage"))
        puts cyan("Generating XML coverage report")
        cmdline = "report /ReportType=XML /Source=\"#{mastercoveragesnapshotfile}\" /Output=\"#{coveragebasename}.xml\""
        run_command "#{description} (XML)", cmdline
        puts cyan("Generating HTML coverage report")
        cmdline = "report /ReportType=HTML /Source=\"#{mastercoveragesnapshotfile}\" /Output=\"#{coveragebasename}.html\""
        run_command "#{description} (HTML)", cmdline
    end
    
    def delete(snapshots)
        puts cyan("Deleting coverage snapshot files")
        description = "dotCover delete snapshots"
        source = [snapshots].flatten.join(";")
        cmdline = "delete /Source=\"#{source}\""
        run_command "#{description}", cmdline
    end
end
