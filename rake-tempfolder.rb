require "fileutils"

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
