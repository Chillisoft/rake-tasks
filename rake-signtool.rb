require "albacore"
require "runcommandwithfail"
require "rake-settings"

class Signtool
    include Albacore::Task
    include Albacore::RunCommand

    # SHA1 of the signing certificate
    #   (no default)
    attr_accessor :certificate_sha1

    # assembly file to be signed
    #   (no default)
    attr_accessor :assembly

    # true to also timestamp the file (BEWARE of timestamp frequency limitations of the timestamping server)
    #   (default false)
    attr_accessor :should_timestamp

    # RFC3161 timestamping server to use
    #   (no default)
    attr_accessor :timestamp_server

    def execute
        @command = $signtool_exe

        params = ["sign"]
        params << "/sha1" << @certificate_sha1 if @certificate_sha1
        params << "/tr" << @timestamp_server if @should_timestamp
        params << assembly

        run_command("signtool", params)
    end
end
