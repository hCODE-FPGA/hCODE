require 'jimson'
module Pod
  class Command
    class Fpga < Command
      #-----------------------------------------------------------------------#
      #Burn an IP bitstream to FPGA
      #-----------------------------------------------------------------------#
      class Program < Fpga
      	self.summary = 'Program an IP bitstream to FPGA.'

        self.description = <<-DESC
          Program a bitstream file to FPGA in local or remote.
          If a folder is given, find all *.bit files for you to choose to program.
        DESC

        self.arguments = [
          CLAide::Argument.new('FOLDER_OF_BITSTREAM', true),
          CLAide::Argument.new('--fpga=FPGA_ID', false),
          CLAide::Argument.new('--remote=HOST_OR_IP', false),
        ]

        def initialize(argv)
          @bitstream_file = argv.shift_argument
          @fpga_id = argv.option('fpga')
          @remote_name = argv.option('remote')
          super
        end

        def validate!
          super
          help! 'A name of a bitstream file, or a folder contains bitstream files (*.bit) is required.' unless @bitstream_file
        end

        def run
          @burn_tcl = ""
          @fpga_id = 0 if !@fpga_id

        	require 'find'
        	bit_file_paths = []
		      Find.find(@bitstream_file) do |path|
		        bit_file_paths << path if path =~ /.*\.bit$/
		      end
          hcode_file = "#{@bitstream_file}/hcode"
          if !File.file?(hcode_file)
            UI.puts "Bitstream defination hcode file is not found in #{@bitstream_file}."
            exit
          end
	        if bit_file_paths.length > 1
	          message = "Please choose a bitstream.".green
	          bit_index = UI.choose_from_array(bit_file_paths, message)
            bit_file = bit_file_paths[bit_index]
	        elsif bit_file_paths.length == 1
	          UI.puts "Found bitstream #{bit_file_paths[0]}."
	          bit_file = bit_file_paths[0]
	        else
	          UI.puts "No bitstream is found in folder #{@bitstream_file}.".red
	          exit
	        end
          burn_tcl = prepare_tcl(bit_file, @fpga_id)
          @remote_name = "http://127.0.0.1" if(!@remote_name)
          program_remote(bit_file, hcode_file, burn_tcl)
    	  end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def prepare_tcl(bit_file, fpga_id)
        	<<-SPEC

open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] #{fpga_id}]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE \{$DIR_HOME/.hcode/temp/bitstream.bit\} [lindex [get_hw_devices] 0]
program_hw_devices [lindex [get_hw_devices] 0]
refresh_hw_device [lindex [get_hw_devices] 0]

          SPEC
        end

        def program_remote(bit_file, hcode_file, burn_tcl)
          require 'base64'
          hcode_spec = File.read(hcode_file)
          bitstream = File.binread(bit_file)
          bitstream_b64 = Base64.encode64(bitstream)

          param = Hash.new
          param["fpga_id"] = @fpga_id
          param["bit_file"] = bit_file
          param["burn_tcl"] = burn_tcl
          param["hcode"] = hcode_spec
          param["user"] = ENV['USER']

          client = Jimson::Client.new("#{@remote_name}:8999")
          result = client.program_slave(param,bitstream_b64) 
          puts result
        end

      end
    end
  end
end
