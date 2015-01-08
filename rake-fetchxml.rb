require 'rexml/document'
include REXML

module FetchXml
    def from_file(filename, value_element, value_attribute=nil)
        values = []
        xmlfile = File.new(filename)
        xmldoc = Document.new(xmlfile)
        xmldoc.elements.each(value_element) do |ele|
            if value_attribute.to_s.strip.length == 0
                # It's nil, empty, or just whitespace
                values << ele.text
            else
                values << ele.attributes[value_attribute]
            end
        end
        return values
    end
    module_function :from_file
end
