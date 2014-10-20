require 'albacore'
require 'rbconfig'
include RbConfig
require 'rake-nuget.rb'
require 'rake-cspkg.rb'
require 'rake-autover.rb'
require 'rake-innosetup.rb'
require 'rake-packagemanifest.rb'

if RbConfig::CONFIG['build'] =~ /mswin/i or RbConfig::CONFIG['build'] =~ /mingw32/i
	require 'win32console'
	$showcolours = true
end

$nunit_console = ''
$nunit_console_prefered = 'C:/Program Files (x86)/NUnit 2.6.3/bin/nunit-console-x86.exe'
$dotcover_console = 'C:/Program Files (x86)/Jetbrains/dotCover/v2.7/Bin/dotcover.exe'
$sonar_runner_path = 'C:/Sonar/sonar-runner-2.3/bin/sonar-runner.bat'

def dotcover_additional_versions
	[	"C:/Program Files (x86)/Jetbrains/dotCover/v2.6/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v2.5/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v2.4/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v2.3/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v2.2/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v2.1/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v1.1/Bin/dotcover.exe",
		"C:/Program Files (x86)/Jetbrains/dotCover/v1.2/Bin/dotcover.exe"
	]
end

def nunit_additional_versions
	[	"C:/Program Files (x86)/NUnit 2.6.2/bin/nunit-console-x86.exe",
		"C:/Program Files (x86)/NUnit 2.6.1/bin/nunit-console-x86.exe",
		"C:/Program Files (x86)/NUnit 2.6/bin/nunit-console-x86.exe",
		"C:/Program Files (x86)/NUnit 2.5.10/bin/net-2.0/nunit-console-x86.exe"
	]
end

class Dotcover
	include Albacore::Task
	include Albacore::RunCommand

	@myassemblies
	@myfilters
	@mynunitoptions = ""

	def assemblies ass
		@myassemblies = ass
	end

	def filters fil
		@myfilters = fil
	end

	def nunitoptions opts
		@mynunitoptions = opts
	end

	def execute
		$nunit_console = FileSystem.ValidFile($nunit_console_prefered, nunit_additional_versions)
		@command = FileSystem.ValidFile($dotcover_console, dotcover_additional_versions)
		ass = @myassemblies.collect { |a| Dir.pwd + "\\" + a }.join(" ")
		nunit_options = "\"#{ass} /xml=#{Dir.pwd}/nunit-result.xml"
		nunit_options += " " + @mynunitoptions.to_s if @mynunitoptions.to_s.length > 0
		nunit_options += "\""
		run_command "dotcover console coverage analysis", "cover /TargetExecutable=\"#{$nunit_console}\" /AnalyseTargetArguments=false /TargetArguments=#{nunit_options} /Output=coveragesnapshot /Filters=#{@myfilters} "
		run_command "dotcover console coverage report (xml)", "report /Source=coveragesnapshot /Output=buildreports/coverage.xml /ReportType=XML"
		run_command "dotcover console coverage report (html)", "report /Source=coveragesnapshot /Output=buildreports/coverage.html /ReportType=HTML"
		FileUtils.rm Dir.glob('coveragesnapshot')
	end

  def run_command(name, parameters)
    print("local run_command")
    ret = super(name, parameters)
    if ret == nil
      fail_with_message "Unable to run dotcover command:\n" + @command + " " + parameters
end
    if ret != true
      fail_with_message "dotcover fails! (command was:\n" + @command + " " + parameters + "\n)"
    end
  end
end

Albacore.configure do |config|
	$nunit_console = FileSystem.ValidFile($nunit_console_prefered, nunit_additional_versions)
	config.log_level = :quiet
	config.nunit do |nunit|
    nunit.command = $nunit_console
    nunit.options = ["/xml=nunit-result.xml"]
  end
end

def colorize(text, color_code)
	if $showcolours
		"#{color_code}\e[1m#{text}\e[0m"
	else
		text
	end
end

def red(text); colorize(text, "\e[31m"); end
def green(text); colorize(text, "\e[32m"); end
def yellow(text); colorize(text, "\e[33m"); end
def blue(text); colorize(text, "\e[34m"); end
def magenta(text); colorize(text, "\e[35m"); end
def cyan(text); colorize(text, "\e[36m"); end

task :create_temp do
	FileUtils.mkdir_p 'temp'
	FileUtils.remove_dir 'temp'
	FileUtils.mkdir_p 'temp'
	FileUtils.mkdir_p 'temp/bin'
end

task :delete_temp do
	FileUtils.mkdir_p 'temp'
	FileUtils.remove_dir 'temp'
end

require 'rexml/document'
include REXML

module FetchXml

	def from_file (filename ,value_element, value_attribute=nil)
		values = []
		xmlfile = File.new(filename)
		xmldoc = Document.new(xmlfile)
		xmldoc.elements.each(value_element) do |ele|
		  if value_attribute.to_s.strip.length == 0
			# It's nil, empty, or just whitespace
			values << ele.text
		  else
			values << ele.attributes[value_attribute]
		  end
		end
		return values
	end
	module_function :from_file
end

module CSVFile
	def create(filename, rowArray)
		myfile = File.open(filename, "w")
		rowArray.each{|row| myfile.puts(row.join(","))}
		myfile.close
	end
	module_function :create
end
