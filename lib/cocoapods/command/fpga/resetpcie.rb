module Pod
  class Command
    class Fpga < Command
      #-----------------------------------------------------------------------#
      #Burn an IP bitstream to FPGA
      #-----------------------------------------------------------------------#
      class Resetpcie < Fpga
      	self.summary = 'Reset the PCIe connection of FPGA.'

        self.description = <<-DESC
          The PCIe connection will be lost after FPGA reconfiguration.
          This reset bringing up accelerator without reboot of host PC.
        DESC

        def initialize(argv)
          super
        end


        def run
          @script_tcl = prepare_tcl()

      	  UI.puts "Start to reset the FPGA PCIe connection."
      	  File.write(".hcode.script.resetpcie.sh", @burn_tcl)
      	  system "sudo sh .hcode.script.resetpcie.sh"
      	  UI.puts "Success: PCIe is reset, your accelerator should be work now."
      	  system "rm -rf .hcode.script.resetpcie.sh"
        end

        private
        #----------------------------------------#

        # !@group Private helpers

        extend Executable
        executable :git

        def prepare_tcl()
        	<<-SPEC

echo 1 |sudo tee /sys/bus/pci/devices/*$(lspci | grep Xilinx | awk '{print $1}')/remove
echo 1 |sudo tee /sys/bus/pci/rescan

          SPEC
        end
      end
    end
  end
end