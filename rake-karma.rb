require "rake"
require "albacore"
require "fileutils"
require "runcommandwithfail"
require "rake-support"
require "rake-nodejs"

class Karma
    include Albacore::Task
    include RunCommandWithFail
    include Rake::DSL

    # base location of the web project (also location of karma.conf.js)
    #   (default ".")
    attr_accessor :base

    # location where test results are stored
    #   (default "buildreports/")
    attr_accessor :reports

    # true to run a single set of tests, or false to run continuously
    #   (default false)
    attr_accessor :singlerun

    # true for coverage report (implies singlerun), or false for normal reporting
    #   (default false)
    attr_accessor :coverage

    # list of browsers to run the tests in
    #   (default "Chrome" for coverage and continuous, "Chrome,Firefox,IE" for singlerun)
    attr_accessor :browsers

    def initialize
        @base = "."
        @reports = "buildreports"

        @buildscripts = File.dirname(__FILE__)
        @karma = File.join(@buildscripts, "node_modules/.bin", "karma.cmd")
        unless @karma.nil?
            @karma = File.expand_path(@karma) if File.exists?(@karma)
        end

        npm = Npm.new
        npm.base = @buildscripts
        npm.update

        super()
    end

    def cleanupTests
        reports = File.expand_path(File.join(@base, @reports))
        FileUtils.rm Dir["#{reports}/TEST-*.xml"]
        FileUtils.rm Dir["#{reports}/test-*.xml"]
    end

    def cleanupCoverage
        reports = File.expand_path(File.join(@base, @reports))
        FileUtils.rm_rf("#{reports}/coverage/lcov-report")
        FileUtils.rm Dir["#{reports}/cobertura-coverage.xml"]
        FileUtils.rm_rf("#{reports}/coverage")
        FileUtils.rm Dir["#{reports}/coverage*.*"]
        FileUtils.rm_rf("#{reports}/lcov-report")
        FileUtils.rm Dir["#{reports}/lcov.info"]
    end

    def copyCoverageReport
        reports = File.expand_path(File.join(@base, @reports))

        latestJson = FileSystem.NewestMatchingFile("#{reports}/*/coverage*.json")
        if latestJson.nil?
            puts yellow("WARNING: Could not find latest Json coverage report. Ensure Karma has JSON coverageReporter configured")
            return
        end
        puts "Moving coverage.json to #{reports}"
        FileUtils.mv(latestJson, "#{reports}/coverage.json")

        latestCoverage = File.dirname(latestJson)

        latestCobertura = "#{latestCoverage}/cobertura-coverage.xml"
        if not File.exist?(latestCobertura)
            puts yellow("WARNING: Could not find latest Cobertura coverage report")
        else
            puts "Moving cobertura-coverage.xml to #{reports}"
            FileUtils.mv(latestCobertura, "#{reports}/")
        end
        latestLcovData = "#{latestCoverage}/lcov.info"
        if not File.exist?(latestLcovData)
            puts yellow("WARNING: Could not find latest LCOV coverage data")
        else
            puts "Moving lcov.info to #{reports}"
            FileUtils.mv(latestLcovData, "#{reports}/")
        end
        latestLcovHtml = "#{latestCoverage}/lcov-report"
        if not File.exist?(latestLcovHtml)
            puts yellow("WARNING: Could not find html lcov-report for coverage")
        else
            puts "Moving html lcov-report to #{reports}/coverage"
            FileUtils.mv(latestLcovHtml, "#{reports}/coverage/")
        end
    end

    def istanbulCsvSummary
        @working_directory = @buildscripts

        reports = File.expand_path(File.join(@base, @reports))
        params = "\"#{reports}\""

        nodejs do |node|
            node.base = @buildscripts
            node.script = "coverage-csv"
            node.parameters = params
        end
        Rake::Task[:nodejs].execute
        Rake::Task[:nodejs].clear
    end

    def getParams
        params = ["start"]
        params << "--colors"

        params << "--no-single-run" unless @coverage || @singlerun
        params << "--single-run" if @coverage || @singlerun

        params << "--auto-watch" unless @coverage || @singlerun
        params << "--no-auto-watch" if @coverage || @singlerun

        browsers = @browsers
        if browsers.nil?
            browsers = "Chrome,Firefox,IE" if @singlerun
            browsers = "Chrome" if @coverage
        end
        params << "--browsers #{browsers}" unless browsers.nil?

        params << "--reporters nested" unless @singlerun || @coverage
        params << "--reporters nested,junit,sonarqubeUnit" if @singlerun
        params << "--reporters nested,coverage" if @coverage

        params << "--report-slower-than 0" unless @singlerun || @coverage

        params
    end

    def installNodePrerequisites
        puts "Checking Karma pre-requisites"
        npm = Npm.new
        npm.base = @base
        npm.require(
            "karma" => "",
            "karma-chrome-launcher" => "",
            "karma-firefox-launcher" => "",
            "karma-ie-launcher" => "",
            "karma-nested-reporter" => "",
            "karma-coverage" => ">=0.5.3",
            "karma-junit-reporter" => ">=0.3.8",
            "karma-sonarqube-unit-reporter" => ">=0.0.2"
        )
    end

    def execute
        installNodePrerequisites
        cleanupTests unless @coverage
        cleanupCoverage

        puts yellow("BEWARE: Minimising browser test window(s) will make testing SLOW!")

        @command = @karma
        @working_directory = @base
        params = getParams

        run_command("Karma", params)

        copyCoverageReport if @coverage
        istanbulCsvSummary if @coverage
    end
end
