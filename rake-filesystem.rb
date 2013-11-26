require "fileutils"
require "find"

module FileSystem

	def FileSystem.EnsurePath(path)
		ensure_dir_exists(path)
	end
	
	def FileSystem.ensure_dir_exists(d)
		parts = d.split(File::SEPARATOR)
		test = nil
		for p in parts
			if test
				test += File::SEPARATOR
				test += p
			else
				test = p
			end
			if !Dir.exist?(test)
				Dir.mkdir(test)
			end
		end
	end

	def FileSystem.ValidFile(prefered,choices) 
		if File.exist?(prefered) then 
			puts ("Found Prefered file : " + prefered)
			return prefered
		end
		choices.each{
		|filetocheck| 
		if File.exist?(filetocheck) then
			puts ("Prefered file: "+ prefered +" , not found consider updating your version, using : " + filetocheck)
			return filetocheck
		end
		}
		return ""
	end
	
	def FileSystem.DeleteDirectory(path)
		if Dir.exists?(path) then 
			 FileUtils.rm_rf path
		end
	end

	def FileSystem.CopyFiles(source, target) 
		Dir.glob(source) do |name|
			FileUtils.cp(name, target)
		end	
	end

	def FileSystem.CopyDlls(source, target) 	
		CopyWithFilter source, target, "*.dll"
	end

	def FileSystem.CopyExecutables(source, target) 	
		CopyWithFilter source, target, "*.exe"
	end

	def FileSystem.CopyWithFilter(source, target, filter)
		# will copy files from source folder to target folder that match the filter. filter example : "*.dll"
		FileUtils.cp_r  Dir.glob( source + "/**/#{filter}"), target
	end
		
	def FileSystem.CopyFilesWithoutSVN(source_path, target_path)
		# Dir.glob("#{source}/**/*").reject{|f| f =~ /^\.svn/}.each do |oldfile|
			# newfile = target + oldfile.sub(source, '')
			# File.file?(oldfile) ? FileUtils.copy(oldfile, newfile) : FileUtils.mkdir(newfile)
		# end
		Find.find(source_path) do |source|
			target = source.sub(/^#{source_path}/, target_path)
			if File.directory? source
				Find.prune if File.basename(source) == '.svn'
				FileUtils.mkdir target unless File.exists? target
			else
				FileUtils.copy source, target
			end
		end
	end
	
	def FileSystem.rubypath(winpath)
		winpath.gsub!( "\\","/" )
	end

	def FileSystem.winpath(rubypath) 
		rubypath.gsub!( "/", "\\" ) 
	end
end
