module Pod
  class Command
    class Ip < Command
      #-----------------------------------------------------------------------#
      #Burn an IP bitstream to FPGA
      #-----------------------------------------------------------------------#
      class Program < Ip
      	self.summary = 'Program an IP bitstream to FPGA.'

        self.description = <<-DESC
          Program a bitstream file to FPGA.
          If a folder is given, find all *.bit files for you to choose to program.
        DESC

        self.arguments = [
          CLAide::Argument.new('FILE_OR_FOLDER', true),
        ]

        def initialize(argv)
          @bitstream_file = argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A name of a bitstream file, or a folder contains bitstream files (*.bit) is required.' unless @bitstream_file
        end

        def run
          @burn_tcl = ""
          if File.file?(@bitstream_file)
          	@burn_tcl = prepare_tcl(@bitstream_file)
          else
          	require 'find'
          	bit_file_paths = []
			Find.find(@bitstream_file) do |path|
			  bit_file_paths << path if path =~ /.*\.bit$/
			end

	        if bit_file_paths.length > 1
	          message = "Please choose a bitstream.".green
	          bit_index = UI.choose_from_array(bit_file_paths, message)
	          @burn_tcl = prepare_tcl(bit_file_paths[bit_index])
	        elsif bit_file_paths.length == 1
	          UI.puts "Found bitstream #{bit_file_paths[0]}."
	          @burn_tcl = prepare_tcl(bit_file_paths[0])
	        else
	          UI.puts "No bitstream is found in folder #{@bitstream_file}.".red
	          exit
	        end
			
      	  end
      	  UI.puts "Start to program the FPGA."
      	  File.write(".hcode.script.program.tcl", @burn_tcl)
      	  system "vivado -nolog -nojournal -mode batch -source .hcode.script.program.tcl"
      	  UI.puts "Success: FPGA is programmed."
        end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def prepare_tcl(bit_file)
        	<<-SPEC

open_hw
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE \{#{bit_file}\} [lindex [get_hw_devices] 0]
program_hw_devices [lindex [get_hw_devices] 0]
refresh_hw_device [lindex [get_hw_devices] 0]

          SPEC
        end
      end
    end
  end
end