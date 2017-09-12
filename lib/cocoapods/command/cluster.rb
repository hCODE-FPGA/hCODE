require 'cocoapods/command/cluster/master'
require 'cocoapods/command/cluster/slave'
require 'cocoapods/command/cluster/status'


module Pod
  class Command
    class Cluster < Command
      self.abstract_command = true
      self.summary = 'Cluster management.'
    end
  end
end
