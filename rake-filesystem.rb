require "fileutils"
require "find"
require "rake-support"

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

    # Cross-platform way of finding an executable in the $PATH.
    #   find_executable('ruby') #=> /usr/bin/ruby
    def FileSystem.FindExecutable(cmd)
        exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
            exts.each { |ext|
                exe = File.join(path, "#{cmd}#{ext}")
                return exe if File.executable?(exe) && !File.directory?(exe)
            }
        end
        return nil
    end

    def FileSystem.ValidFile(prefered, alternatives)
        if File.exist?(prefered) then
            puts("Found Prefered file #{prefered}")
            return prefered
        end
        alternatives.each { |filetocheck|
            if File.exist?(filetocheck) then
                puts yellow("Prefered file #{prefered} not found (consider updating your version). Using #{filetocheck}")
                return filetocheck
            end
        }
        puts yellow("Prefered file #{prefered} not found. Attempting to use default version")
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

    def FileSystem.CopyWithFolders(files, dest, src_root)
        files.each do |file|
            fileWithFolder = file.sub(/^#{src_root}/i, '')
            dest_dir = File.dirname(File.join(dest, fileWithFolder))
            FileUtils.mkdir_p dest_dir
            FileUtils.cp(file, dest_dir)
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

    def FileSystem.NewestMatchingFile(wildcard)
        Dir.glob(wildcard).max_by {|f| File.mtime(f)}
    end

    def FileSystem.rubypath(winpath)
        winpath.gsub!( "\\","/" )
    end

    def FileSystem.winpath(rubypath)
        rubypath.gsub!( "/", "\\" )
    end

    def FileSystem.CaptureOutput(filename)
        previous_stdout = STDOUT.dup
        STDOUT.reopen(filename)
        STDOUT.sync = true
        yield
    ensure
        STDOUT.reopen(previous_stdout)
        if RUBY_VERSION < "2.0.0"
            # Win32Console doesn't recover properly after being redirected
            # So we have to reinitialise it here
            require "rbconfig"
            if RbConfig::CONFIG['build'] =~ /mswin/i or RbConfig::CONFIG['build'] =~ /mingw32/i
                require "win32console"
                $stdout = Win32::Console::ANSI::IO.new(:stdout)
            end
        end
    end
end
