require 'rake'
require 'albacore'
require 'rake-settings.rb'	
require 'rake-filesystem.rb'

class Compress
	include Albacore::Task
	include Rake::DSL

	attr_accessor 	:zip_filename,
					:file_pattern,
					:recurse_subdirectories
									
	def initalize
		@recurse_subdirectories = true;
	end
		
	def execute
		exec :zip do |cmd|		
			windows_file_pattern = @file_pattern.gsub('/','\\')
			
			params = "a -tzip #{@zip_filename} #{windows_file_pattern}"
			if @recurse_subdirectories==true
				params = params + " -r"
			end	
			cmd.command = "#{File.dirname(__FILE__)}/7za/7za.exe"
			puts cyan("Command : #{cmd.command} #{params}")

			cmd.parameters params
		end
		
		Rake::Task[:zip].execute
		Rake::Task[:zip].clear
	end
	
end

# example syntax for compress
# NOTE: If you don't specify the full path for zip_filename, file_pattern, etc 7Zip will work relative to the 7Zip.exe#compress :docompress do |zip|
#	zip.zip_filename = "#{Dir.pwd}/temp/wibble.zip"
#	zip.file_pattern = "#{Dir.pwd}/source/AMS.CentralDb.Tests/*.cs"
#	zip.recurse_subdirectories = false
#end

class Decompress
	include Albacore::Task
	include Rake::DSL

	attr_accessor 	:zip_filename,
					:output_directory,
					:flatten_directories
					
	def Initialize
		@flatten_directories = false
		@output_directory = "temp"
	end
	
	def execute
		exec :unzip do |cmd|
			puts cyan(@output_directory)
			FileSystem.EnsurePath @output_directory
			windows_output_directory = "\"#{Dir.pwd}/#{@output_directory}\"".gsub('/','\\')
			
			extract_mode = "e"
			if @flatten_directories!=true
				extract_mode = "x"
			end
			
			params = "#{extract_mode} -tzip #{@zip_filename} -o#{windows_output_directory}"

			puts cyan("Command : 7za #{params}")
			cmd.command = "#{File.dirname(__FILE__)}/7za/7za.exe"
			cmd.parameters params
		end
		
		Rake::Task[:unzip].execute
		Rake::Task[:unzip].clear
	end
end

# example syntax for decompress
# NOTE: If you don't specify the full path for zip_filename, output_directory, etc 7Zip will work relative to the 7Zip.exe
#decompress :dodecompress do |unzip|
#	unzip.zip_filename = "#{Dir.pwd}/temp/wibble.zip"
#	unzip.output_directory = "#{Dir.pwd}/temp"
#	unzip.flatten_directories = true
#end