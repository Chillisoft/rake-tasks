module CSVFile
    def create(filename, rowArray)
        myfile = File.open(filename, "w")
        rowArray.each{|row| myfile.puts(row.join(","))}
        myfile.close
    end
    module_function :create
end
