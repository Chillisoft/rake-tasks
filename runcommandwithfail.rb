require "albacore"

module RunCommandWithFail
    include Albacore::RunCommand
    
    def run_command(name="Command Line", parameters=nil)
        ret = super(name, parameters)
        if ret == nil
          fail_with_message "Unable to run command: #{@command} #{parameters}"
        end
        if ret != true
          fail_with_message "command failed: #{@command} #{parameters}"
        end
        ret
    end
end
