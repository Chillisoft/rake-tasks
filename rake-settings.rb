require "albacore"
require "rake-filesystem"

$nunit_console = "C:/Program Files (x86)/NUnit 2.6.3/bin/nunit-console-x86.exe"
$nunit_additional_versions = [
        "C:/Program Files (x86)/NUnit 2.6.2/bin/nunit-console-x86.exe",
        "C:/Program Files (x86)/NUnit 2.6.1/bin/nunit-console-x86.exe",
        "C:/Program Files (x86)/NUnit 2.6/bin/nunit-console-x86.exe",
        "C:/Program Files (x86)/NUnit 2.5.10/bin/net-2.0/nunit-console-x86.exe"
    ]

$dotcover_console = "C:/Program Files (x86)/Jetbrains/dotCover/v2.7/Bin/dotcover.exe"
$dotcover_additional_versions = [
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.6/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.5/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.4/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.3/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.2/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v2.1/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v1.2/Bin/dotcover.exe",
        "C:/Program Files (x86)/Jetbrains/dotCover/v1.1/Bin/dotcover.exe"
    ]

$sonar_runner_path = "C:/Sonar/sonar-runner-2.3/bin/sonar-runner.bat"

Albacore.configure do |config|
    $nunit_console = FileSystem.ValidFile($nunit_console, $nunit_additional_versions)
    $dotcover_console = FileSystem.ValidFile($dotcover_console, $dotcover_additional_versions)
    buildreports = File.expand_path("buildreports")
    FileSystem.EnsurePath(buildreports)
    result_xml = File.join(buildreports, "nunit-result.xml")
    config.log_level = :quiet
    config.nunit do |nunit|
        nunit.command = $nunit_console
        nunit.options = [ "/xml=\"#{result_xml}\"" ]
    end
end

## For backward compatibility only
require "rake-support"
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
