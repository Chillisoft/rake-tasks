# This is the master bootstrapper for all rake tasks
# You need to require only this file to include all standard rake tasks
# Updates the rake-tasks to latest version before loading standardtasks

def include_path_to_rake_tasks
    this_path = File.dirname(__FILE__)
    raketaskspath = File.expand_path(this_path)
    $:.unshift(raketaskspath) unless
        $:.include?(this_path) || $:.include?(raketaskspath)
end

include_path_to_rake_tasks

# pull in rake support functions
require "rake-support"

# update git submodules, ensuring the rake-tasks are at the latest version
update_git_submodules

# reload rake support functions just in case they have been updated
Kernel::load "rake-support.rb"

# after updating, pull in all the updated tasks
require "rake-standardtasks"
