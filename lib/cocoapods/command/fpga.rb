require 'cocoapods/command/fpga/program'
require 'cocoapods/command/fpga/resetpcie'

module Pod
  class Command
    class Fpga < Command
      self.abstract_command = true
      self.summary = 'FPGA helper scripts set.'
    end
  end
end