gem "albacore", "~>0.3"
require "albacore"
require "rake-filesystem"
require "rubygems"

$nunit_console = "#{ENV['ProgramFiles(x86)']}/NUnit.org/nunit-console/nunit3-console.exe"
$nunit_additional_versions = [
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.6.4/bin/nunit-console-x86.exe",
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.6.3/bin/nunit-console-x86.exe",
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.6.2/bin/nunit-console-x86.exe",
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.6.1/bin/nunit-console-x86.exe",
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.6/bin/nunit-console-x86.exe",
        "#{ENV['ProgramFiles(x86)']}/NUnit 2.5.10/bin/net-2.0/nunit-console-x86.exe"
    ]

$dotcover_console = "#{ENV['ProgramFiles(x86)']}/JetBrains/Installations/dotCover06/dotCover.exe"
$dotcover_additional_versions = [
        "#{ENV['LOCALAPPDATA']}/JetBrains/Installations/dotCover06/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/JetBrains/Installations/dotCover05/dotCover.exe",
        "#{ENV['LOCALAPPDATA']}/JetBrains/Installations/dotCover05/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/JetBrains/Installations/dotCover04/dotCover.exe",
        "#{ENV['LOCALAPPDATA']}/JetBrains/Installations/dotCover04/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/JetBrains/Installations/dotCover03/dotCover.exe",
        "#{ENV['LOCALAPPDATA']}/JetBrains/Installations/dotCover03/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/JetBrains/Installations/dotCover02/dotCover.exe",
        "#{ENV['LOCALAPPDATA']}/JetBrains/Installations/dotCover02/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v3.1/Bin/dotCover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.7/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.6/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.5/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.4/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.3/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.2/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v2.1/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v1.2/Bin/dotcover.exe",
        "#{ENV['ProgramFiles(x86)']}/Jetbrains/dotCover/v1.1/Bin/dotcover.exe"
    ]

$sonar_runner = "C:/Sonar/sonar-runner-2.4/bin/sonar-runner.bat"
$sonar_runner_additional_versions = [
        "C:/Sonar/sonar-runner-2.3/bin/sonar-runner.bat"
    ]

$signtool_exe = "#{ENV['ProgramFiles(x86)']}/Windows Kits/8.1/bin/x64/signtool.exe"
$signtool_additional_versions = [
        "#{ENV['ProgramFiles(x86)']}/Windows Kits/8.0/bin/x64/signtool.exe"
    ]

def getLatestMSBuild
    installationPath = `#{File.dirname(__FILE__)}/vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`
    installationPath = "#{ENV['ProgramFiles(x86)']}" if installationPath.nil? || installationPath.empty?
    msbuilds = Dir.glob("#{FileSystem.rubypath(installationPath)}/MSBuild/**/Bin/msbuild.exe")
    latestMsbuild = msbuilds.sort_by { |path| Gem::Version.new(path.split("/")[-3]) }.last
    if File.exist?(latestMsbuild) then
        puts "Found MSBuild at #{latestMsbuild}"
        return latestMsbuild
    end
    puts yellow("Latest MSBuild not found. Attempting to use default version")
    return ""
end

Albacore.configure do |config|
    $msbuild_exe = getLatestMSBuild()
    $nunit_console = FileSystem.ValidFile($nunit_console, $nunit_additional_versions)
    $dotcover_console = FileSystem.ValidFile($dotcover_console, $dotcover_additional_versions)
    $sonar_runner = FileSystem.ValidFile($sonar_runner, $sonar_runner_additional_versions)
    $signtool_exe = FileSystem.ValidFile($signtool_exe, $signtool_additional_versions)
    config.log_level = :quiet
end

## For backward compatibility only
require "rake-support"
require "rake-nunit"
require "rake-dotcover"
require "rake-fetchxml"
require "rake-csvfile"
require "rake-tempfolder"
require "rake-git"
require "rake-nuget"
require "rake-cspkg"
require "rake-autover"
require "rake-innosetup"
require "rake-packagemanifest"
