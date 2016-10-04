# Must NOT use any local dependencies here,
#  otherwise issues will arise when auto-updating rake-tasks as a sub-module
require "rbconfig"
include RbConfig

# Setup colourized console output
if RbConfig::CONFIG["build"] =~ /mswin/i or RbConfig::CONFIG["build"] =~ /mingw32/i
    require "win32console" unless RUBY_VERSION >= "2.0.0"
    $showcolours = true
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

def update_git_submodules
    puts cyan("Updating Git Submodules")
    system "git submodule update --init --recursive"
    system "git submodule foreach --recursive git fetch"
    system "git submodule foreach --recursive git checkout origin"
end
