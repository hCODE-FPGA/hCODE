require 'cocoapods/command/shell/get'

module Pod
  class Command
    class Shell < Command
      self.abstract_command = true
      self.summary = 'Develop with hardware Shell'
    end
  end
end
