require 'rake'
require 'albacore'
require 'rexml/document'
require 'pathname'


class PackageManifest
  include Albacore::Task
  include Rake::DSL

  attr_accessor :BasePath # base folder to inspect
  attr_accessor :PackageName # name of package to reflect
  attr_accessor :PackageVersion # package version to reflect
  attr_accessor :EntryPoint # what to place in the executable attribute (optional; required for ChilliStart)
  attr_accessor :PackageType # defaults to "program"
  LogPrefix = "PackageManifest task: "
  ManifestFileName = "manifest.xml"

  def execute()
    check_parameters()
    doc = build_document()
    write_doc(doc)
  end

  def write_doc(doc)
    docPath = File.join(@BasePath, "manifest.xml")
    puts yellow("#{LogPrefix} writing package manifest to: #{docPath}")
    xml = ""
    doc.write(xml, 1)
    File.open(docPath, "w") do |file|
      file.puts(xml)
    end
  end

  def build_document()
    puts yellow("#{LogPrefix}Building package manifest")
    doc = generate_document_root()
    add_file_nodes(doc)
    return doc
  end

  def add_file_nodes(doc)
    basePath = Pathname.new(@BasePath)
    ls_r(basePath).each do |item|
      itemPath = Pathname.new(item)
      relPath = itemPath.relative_path_from(basePath).to_s
      if (relPath.downcase == "manifest.xml")
        next
      end
      el = doc.root.add_element("file")
      el.attributes["name"] = relPath
      el.attributes["size"] = File.size(item)
    end
  end

  def ls_r(path)
    items = []
    Dir.glob(File.join(path, "*")).each do |item|
      if File.directory?(item)
        items.concat(ls_r(item))
        next
      end
      items.push(item)
    end
    return items
  end

  def generate_document_root()
    doc = REXML::Document.new
    root = doc.add_element("package")
    root.attributes["name"] = @PackageName
    root.attributes["version"] = @PackageVersion
    root.attributes["type"] = @PackageType
    if not @EntryPoint.nil?
      root.attributes["executable"] = @EntryPoint
    end
    return doc
  end
  def check_parameters()
    if @BasePath.nil?
      fail "#{LogPrefix}BasePath not specified"
    end
    if not @BasePath.instance_of?(String)
      fail "#{LogPrefix}BasePath must be a string"
    end
    if not File.directory?(@BasePath)
      fail "#{LogPrefix}Can't find BasePath at: \"#{@BasePath}\""
    end
    if @PackageName.nil?
      fail "#{LogPrefix}PackageName not specified"
    end
    if not @PackageName.instance_of?(String)
      fail "#{LogPrefix}PackageName must be a string"
    end
    if @PackageName.length < 3
      fail "#{LogPrefix}PackageName must be at least 3 characters long"
    end
    if @PackageVersion.nil?
      fail "#{LogPrefix}PackageVersion not set"
    end
    @PackageVersion = @PackageVersion.to_i
    if @PackageVersion < 1
      fail "#{LogPrefix}PackageVersion must be an integer and > 0"
    end
    if @EntryPoint.nil?
      fail "#{LogPrefix}EntryPoint not specified"
    end
    if @EntryPoint.index(@BasePath)
      pnBase = Pathname.new(@BasePath)
      pnEntry = Pathname.new(@EntryPoint)
      @EntryPoint = pnEntry.relative_path_from(pnBase).to_s
    end
    if @PackageType.nil?
      @PackageType = "program"
    end
  end
end
