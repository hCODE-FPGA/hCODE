require 'jimson'
module Pod
  class Command
    class Cluster < Command
      #-----------------------------------------------------------------------#
      #Install a IP
      #-----------------------------------------------------------------------#
      class Slave < Cluster
        extend Jimson::Handler

        self.summary = 'Start hCODE slave server.'

        self.description = <<-DESC
          Setup and start hCODE slave server.
        DESC

        def initialize(argv)
          super
        end

        def run
          check_slave_conf
          server = Jimson::Server.new(Slave.new(CLAide::ARGV.new([])))
          server.start
        end

        def check_slave_conf
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          if !File.exist?(@slave_conf_file)
            slave_conf = Hash.new
            slave_conf["FPGA"] = Hash.new
            UI.puts "Slave configuration file (~/.hcode/slave.conf) does not exist.".red
            UI.puts "Input the following information to create one."
            UI.print "Enter # of FPGAs: "
            num_fpga = UI.gets.chomp.to_i
            UI.puts

            0.upto(num_fpga - 1){|id|
              slave_conf["FPGA"]["#{id}"] = Hash.new
              UI.print "FPGA #{id} - board name (ex. vc707): "
              slave_conf["FPGA"]["#{id}"]["board"] = UI.gets.chomp
              UI.puts
              UI.print "FPGA #{id} - FPGA device name (ex. xc7vx485tffg1761-2): "
              slave_conf["FPGA"]["#{id}"]["device"] = UI.gets.chomp
              UI.puts
            }

            require 'json'
            File.open(@slave_conf_file, 'w') do |file|
              json_str = JSON.pretty_generate(slave_conf)
              str = file.write(json_str)
            end

            UI.puts "Slave configuration file is created (~/.hcode/slave.conf).".green
            UI.puts            
          end
        end

        def get_slave_conf
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          json = File.read(@slave_conf_file)
          return json
        end

        def program_slave(param, bitstream_b64)
          require 'json'
          require 'base64'

          bitstream = Base64.decode64(bitstream_b64)
          File.binwrite("#{Dir.home}/.hcode/temp/bitstream.bit", bitstream)

          hcode_spec = JSON.parse(param["hcode"])
          fpga_id = param["fpga_id"].to_s
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          slave_conf = JSON.parse(File.read(@slave_conf_file))

          if(hcode_spec["shell"]["name"].include?"-pr-")
            #Partial reconfiguration
            hcode_spec["ip"].each{|ip_id, ip_conf|
              ip_conf["conf_user"] = param["user"]
              ip_conf["conf_date"] = Time.new.strftime("%Y-%m-%d %H:%M:%S")
              ip_conf["enable"] = 1 if !ip_conf.has_key?"enable"
              slave_conf["FPGA"][fpga_id]["ip"][ip_id] = ip_conf
            }
            puts "here3"
          else
            #Complete reconfiguration
            slave_conf["FPGA"][fpga_id]["ip"] = Hash.new
            slave_conf["FPGA"][fpga_id]["ip"] = hcode_spec["ip"]
            slave_conf["FPGA"][fpga_id]["shell"] = hcode_spec["shell"]
            slave_conf["FPGA"][fpga_id]["ip"].each{|ip_id, ip_conf|
              ip_conf["conf_user"] = param["user"]
              ip_conf["conf_date"] = Time.new.strftime("%Y-%m-%d %H:%M:%S")
              ip_conf["enable"] = 1 if !ip_conf.has_key?"enable"
            }
          end
          File.open(@slave_conf_file, 'w') do |file|
            json_str = JSON.pretty_generate(slave_conf)
            str = file.write(json_str)
          end
	        lock_ip(fpga_id, -1)
          param["burn_tcl"] = param["burn_tcl"].gsub("$DIR_HOME","#{Dir.home}")

          File.write("#{Dir.home}/.hcode/temp/hcode.script.program.tcl", param["burn_tcl"])
          #system "vivado -nolog -nojournal -mode batch -source #{Dir.home}/.hcode/temp/hcode.script.program.tcl"
	        recover_ip(fpga_id, -1)
          system "rm -rf #{Dir.home}/.hcode/temp/hcode.script.program.tcl"
          system "rm -rf #{Dir.home}/.hcode/temp/bitstream.bit"
        end

        def release_ip(fpga_id, ip_id)
          require 'json'
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          json = File.read(@slave_conf_file)
          slave_conf = JSON.parse(json)
          slave_conf["FPGA"][fpga_id.to_s]["ip"][ip_id.to_s]["enable"] = 0
          File.open(@slave_conf_file, 'w') do |file|
            json_str = JSON.pretty_generate(slave_conf)
            str = file.write(json_str)
          end
        end

        def recover_ip(fpga_id, ip_id)
          require 'json'
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          json = File.read(@slave_conf_file)
          slave_conf = JSON.parse(json)
      	  if(ip_id >= 0)
                  slave_conf["FPGA"][fpga_id.to_s]["ip"][ip_id.to_s]["enable"] = 1 
      	  else
      	    slave_conf["FPGA"][fpga_id.to_s]["ip"].each{|ip_id, ip_conf|
      	      ip_conf["enable"] == 1
                  }
      	  end
          File.open(@slave_conf_file, 'w') do |file|
            json_str = JSON.pretty_generate(slave_conf)
            str = file.write(json_str)
          end
        end        

        def lock_ip(fpga_id, ip_id)
          require 'json'
          @slave_conf_file = "#{Dir.home}/.hcode/slave.conf"
          json = File.read(@slave_conf_file)
          slave_conf = JSON.parse(json)
      	  if(ip_id >= 0)
                  slave_conf["FPGA"][fpga_id.to_s]["ip"][ip_id.to_s]["enable"] = -1 if (slave_conf["FPGA"][fpga_id.to_s]["ip"][ip_id.to_s]["enable"] == 1)
      	  else
      	    slave_conf["FPGA"][fpga_id.to_s]["ip"].each{|ip_id, ip_conf|
      	      ip_conf["enable"] == -1 if(ip_conf["enable"] == 1)
                  }
      	  end
          File.open(@slave_conf_file, 'w') do |file|
            json_str = JSON.pretty_generate(slave_conf)
            str = file.write(json_str)
          end
        end        
     end
    end
  end
end
