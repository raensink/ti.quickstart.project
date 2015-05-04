
# ==============================================================================#=
# FILE:
#   system_command.rb
#
# DESCRIPTION:
#   A lower level utility class for running system commands.
#
# DEPENDENCIES:
#   Gem: open3.
#   All command output is captured internally;
#   output is written neither to STDOUT nor STDERR.
#
# INSTRUCTIONS/EXAMPLES:
#   There is no need to create a new SystemCommand object for each new command;
#   use the 'set' method to reset the internal state of the object.
#
# @@@ TODO @@@
#     add option to log all output while command is in progress @@@@
#     add option to turn off std output capture
# ==============================================================================#=

require 'open3'

class SystemCommand

  def initialize()
    reset_object_state
  end

  private # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-+-

  def reset_object_state
    # Make object ready to start a new command.
    @command_string  = ""
    @captured_stdout = ""
    @captured_stderr = ""
    @process_status  = nil
    @exit_status     = nil
    @success         = false
  end

  def run_command_and_yield_output(cmd, &block)
    # Uses popen3 to run the given command in a sub process.
    # Yields all command output to the given block while the command is running.
    # Returns the Process::Status object of the command sub process.
    cmd_process_status = nil

    begin
      Open3.popen3(cmd) do |cmd_in, cmd_out, cmd_err, cmd_thread|
        # No support for commands that read from input.
        cmd_in.close

        # Use a separate thread to process the command's stdout stream.
        out_thread = Thread.new do
          until (line = cmd_out.gets).nil? do
            yield Hash[:stream => :out, :line => line]
          end
        end

        # Use a separate thread to process the command's stderr stream.
        err_thread = Thread.new do
          until (line = cmd_err.gets).nil? do
            yield Hash[:stream => :err, :line => line]
          end
        end

        # Wait for stream collectors to finish.
        out_thread.join
        err_thread.join

        # Wait for the command sub process to terminate.
        # This returns a Process::Status object.
        cmd_process_status = cmd_thread.value
      end

    rescue Exception => ex
      ex_hash = Hash[:stream => :err, :line => "SystemCommand: exception raised! \n"]
      yield ex_hash
      ex_hash[:line] = "#{ex.message} \n"
      yield ex_hash
    end

    return cmd_process_status

  end ### run_command_and_yield_output() ###

  public # ~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~+~

  def set(given_str = nil)
    reset_object_state
    @command_string = given_str if given_str
    return self
  end

  alias_method :clr, :set

  def <<(given_str)
    @command_string << given_str
    return self
  end

  def str
    return @command_string
  end

  def success?
    return @success
  end

  def stdout
    return @captured_stdout
  end

  def stderr
    return @captured_stderr
  end

  def exit_status
    if @exit_status.nil?
      return 1
    else
      return @exit_status
    end
  end

  def run(given_str = nil)
    #
    # Runs the command string as a system command.
    # Updates the object state to reflect command output and exit status.
    #
    unless given_str.nil?
      reset_object_state
      @command_string = given_str
    end

    @process_status = run_command_and_yield_output(@command_string) do |out_hash|
      # A hash is yielded for each line of output.
      # This hash contains one line of text and
      # and an indicator of whether the line is from stdout or stderr.
      if (out_hash[:stream] == :out)
        @captured_stdout << out_hash[:line]
      end
      if (out_hash[:stream] == :err)
        @captured_stderr << out_hash[:line]
      end
    end
    if @process_status and @process_status.exited?
      @exit_status = @process_status.exitstatus
      @success = true if (@exit_status == 0)
    else
      @captured_stderr << "SystemCommand: command sub process did not exit normally. \n"
    end

    # Returning self here allows the caller
    # to write code like this: if command.run.success?
    return self
  end  ### run() ###

  def lrun(given_logger)
    raise if given_logger.nil?
    given_logger.msg_new "> #{@command_string}"
    if run.success?
      given_logger.msg_continue "Success.  STDOUT is:"
      if @captured_stdout.empty?
        given_logger.msg_indent "empty."
      else
        @captured_stdout.each_line {|line| given_logger.msg_indent line.chomp!}
      end
    else
      given_logger.msg_continue "Failed!  STDERR is:"
      if @captured_stderr.empty?
        given_logger.msg_indent "empty."
      else
        @captured_stderr.each_line {|line| given_logger.msg_indent line.chomp!}
      end
    end
  end

  def check_result_and_return_output()
    # Return the captured stdout, assuming the command was successful.
    # Otherwise, raise an exception.
    if @success
      return @captured_stdout
    else
      msg  = "Command Failure. \n"
      msg += "#{@command_string} \n"
      msg += "#{@captured_stderr} \n"
      raise msg
    end
  end

end ### class SystemCommand ###


__END__
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+-
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+-
puts_ "captured_stderr: #{@captured_stderr}"


