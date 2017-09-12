require 'jimson'
module Pod
  class Command
    class Cluster < Command
      #-----------------------------------------------------------------------#
      #Install a IP
      #-----------------------------------------------------------------------#
      class Master < Cluster
        extend Jimson::Handler

        self.summary = 'Start hCODE master server.'

        self.description = <<-DESC
          Setup and start hCODE master server.
        DESC

        def initialize(argv)
          super
        end

        def run
          client = Jimson::Client.new("http://127.0.0.1:8999") 
          result = client.get_slave_conf 
          puts result
          client.release_ip(0,1)
          result = client.get_slave_conf 
          puts result
        end

      end
    end
  end
end