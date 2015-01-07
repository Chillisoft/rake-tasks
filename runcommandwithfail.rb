require "albacore"

module RunCommandWithFail
    include Albacore::RunCommand
    
    def run_command(name="Command Line", parameters=nil, failWhenCommandFails=true)
        ret = super(name, parameters)
        if ret == nil
          fail_with_message "Unable to run #{name}: #{@command} #{parameters}"
        end
        if ret != true && failWhenCommandFails
          fail_with_message "#{name} failed: #{@command} #{parameters}"
        end
        ret
    end
end
