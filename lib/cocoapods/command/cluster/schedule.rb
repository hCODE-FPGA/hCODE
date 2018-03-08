require 'jimson'
module Pod
  class Command
    class Cluster < Command
      #-----------------------------------------------------------------------#
      #Install a IP
      #-----------------------------------------------------------------------#
      class Schedule < Cluster
        extend Jimson::Handler

        self.summary = 'Deploy IPs on cluster automatically.'

        self.description = <<-DESC
          Deploy IPs on cluster automatically. IP_REPO_NAME format is IP_NAME:IP_TAG:NUMBER.
        DESC

        self.arguments = [
          CLAide::Argument.new('IP_REPO_NAME [IP_REPO_NAME] ...', true),
          CLAide::Argument.new('--constrain=area(default)|speed', false),
        ]

        def initialize(argv)
          @ip_names = argv.arguments!
          @constrain = argv.option('constrain') == "speed" ? 1 : 0
          @ip_names.each{
            argv.shift_argument
          }
          super
        end

        def validate!
          super
          help! 'At lease one IP is required.' if @ip_names.length <= 0
        end

        def run
          #Update cluster status
          update_cluster_status

          #Get ip list & slave list, then schedule
          ip_list = complete_ip_list
          slave_list = load_slaves
          result, ip_scheduled = schedule(slave_list, ip_list)
          ip_scheduled.each{|ip|
            UI.puts "#{ip['name']}: #{ip['determined']} (#{ip['determined_type']})"
          }

          exit

      	  ip_scheduled.each{|ip|
	          UI.puts "hCODE: (#{Time.now.to_s}) Process IP #{ip["name"]}:#{ip["tag"]} on #{ip["determined"]}."
            hcode_file = gene_target_hcode_file(ip, slave_list)
	          hcode_hash_string = ""
            hcode_file["ip"].each{|ip_id, ip|
              hcode_hash_string = hcode_hash_string + "#{ip["name"]}#{ip["tag"]}#{ip["ip_conf"]}#{ip["shell_conf"]}"
            }
            hcode_hash = Digest::SHA256.hexdigest(hcode_hash_string)[0..9]
            hcode_cache = "#{Dir.home}/.hcode/cache/#{hcode_hash}"
	          bit_file = ""
  	        t_slave = ip["determined"].split(":")[0].split("-")[0]
	          t_fpga = ip["determined"].split(":")[0].split("-")[1]
            if File.directory?(hcode_cache)
              UI.puts "hCODE: (#{Time.now.to_s}) Bitstream cache of the same configuration(#{hcode_hash}) is found.".green
	            bit_file = "#{hcode_cache}/bitstream.bit"
	            UI.puts "hCODE: (#{Time.now.to_s}) Program remote FPGA #{t_slave}-#{t_fpga}.".green
 	            system "hcode fpga program --remote=#{t_slave} --fpga=#{t_fpga} #{bit_file}"
	          else
	            hcode_tmp = "#{Dir.home}/.hcode/temp/#{hcode_hash}"
	            system("mkdir #{hcode_tmp}")
              File.open("#{hcode_tmp}/hcode", 'w') do |file|
                json_str = JSON.pretty_generate(hcode_file)
                str = file.write(json_str)
              end
	            system("cd #{hcode_tmp} && hcode ip make .")
	            bit_file = "#{hcode_tmp}/bitstream.bit"
	            UI.puts "hCODE: (#{Time.now.to_s}) Program remote FPGA #{t_slave}-#{t_fpga}.".green
	            system "hcode fpga program --remote=#{t_slave} --fpga=#{t_fpga} #{bit_file}"
	            system("rm -rf #{hcode_tmp}")
            end
          }
	        UI.puts "hCODE: (#{Time.now.to_s}) Scheduling task is finished.".green
        end

        def gene_target_hcode_file(ip, slave_list)
            tmp = ip["determined"].split(":")
            d_slave = tmp[0]
            d_ch    = tmp[1]
            ip_get_string = ""
            s_ip = slave_list.find{|s| s["server"] == d_slave}["ip"]
            s_ip[d_ch] = Hash.new
            s_ip[d_ch]["name"] = ip["name"]
            s_ip[d_ch]["tag"] = ip["tag"]
            in_ip_conf = arg_to_hash(ip["ip_conf"]) if ip["ip_conf"]
            in_shell_conf = arg_to_hash(ip["shell_conf"]) if ip["shell_conf"]
            ip["ip_conf"] = ""
            ip["shell_conf"] = ""
            Find.find(File.expand_path("#{Dir.home}/.hcode/repos/")) do |path|
              if path =~ /.*#{ip["name"]}\/#{ip["tag"]}\/hcode\.spec$/
                json = File.read(path)
                spec = JSON.parse(json)
                spec["shell"][ip["shell"]]["ip_conf"].each{|key, value|
                  value = in_ip_conf[key] if((in_ip_conf) && (in_ip_conf.has_key?key))
                  ip["ip_conf"] += "-#{key} \'#{value}\' "
                }
                ip["ip_conf"] += "-device \'#{ip["device"]}\' "
                ip["shell_conf"] += "-channel \'#{d_ch}\' "
                spec["shell"][ip["shell"]]["shell_conf"].each{|key, value|
                  value = in_shell_conf[key] if((in_shell_conf) && (in_shell_conf.has_key?key))
                  ip["shell_conf"] += "-#{key} \'#{value}\' "
                }
              end
            end
            s_ip[d_ch]["ip_conf"] = ip["ip_conf"]
            s_ip[d_ch]["shell_conf"] = ip["shell_conf"]
            s_shell = slave_list.find{|s| s["server"] == d_slave}["shell"]
            s_shell["name"] = "#{ip["shell"]}-#{s_ip.length}ch"
            s_shell["tag"] = SourcesManager.get_tag_by_name(s_shell["name"])
            hcode_file = Hash.new
            hcode_file["ip"] = s_ip
            hcode_file["shell"] = s_shell
            return hcode_file
        end

      	def arg_to_hash(str)
      	  hash = Hash.new
      	  state = 0
          key = ""
          value = ""
      	  str.each_char{|c|
            if((state == 1) && (c == " "))
              state = 0
              next
            end
            if((state == 2) && (c == "'"))
              state = 0
              hash[key] = value
              next
            end
            if(state == 1)
      	      key = key + c
            end
            if(state == 2)
      	      value = value + c
            end
            if(c == "-")
      	      state = 1
      	      key = ""
            end
            if((state == 0) && (c == "'"))
          		state = 2
          		value = ""
            end
          }
      	  return hash
        end

        def update_cluster_status
          system("hcode cluster status --silent")
        end

        def complete_ip_list
          ip_list = Array.new
          @ip_names.each{|ip_string|
            parts = ip_string.split(":")
            ip = Hash.new
            ip["name"] = parts[0]
            ip["tag"] = parts[1] if(parts.length > 1)
            if ((!ip.has_key? "tag") || (ip["tag"] == ""))
              ip["tag"] = SourcesManager.get_tag_by_name(ip["name"])
            end
            quantity = (parts.length > 2) ? parts[2].to_i : 1
      	    ip["ip_conf"] = parts[3] if(parts.length > 3)
      	    ip["shell_conf"] = parts[4] if(parts.length > 4)            
            1.upto(quantity){|id|
              ip_list.push ip.clone
            }
          }
          return ip_list
        end

        def load_slaves
          require 'json'
          slaves_status_file = "#{Dir.home}/.hcode/slaves_status.log"
          json = File.read(slaves_status_file)
          slaves_resource = JSON.parse(json)

          slaves = Array.new
          slaves_resource.each{|k,v|
            v["server"] = k
            slaves.push v
          }
          return slaves
        end

        def schedule(slaves, ips)
          num_implemented_ip = 0

          #First try unused slaves
          ips.each{|ip|
            target_slave = Hash.new
            #Find a slave that left min resource after implementing this IP
            slaves.each_with_index{|slave, id|
              if((!slave.has_key?"resource") && (!ip.has_key?"determined"))
              #if(!ip.has_key?"determined")
                ip_resource, shell_name = get_ip_resource(ip["name"], ip["tag"], nil, slave["board"])
                next if ip_resource == nil
                slave_resource = get_shell_resource(shell_name)
                result, report = implementable(slave_resource, ip_resource, 1, 0)
                next if !result
                if((!target_slave.has_key?"left_resource") || compare_resource(report, target_slave["left_resource"]))
                  target_slave["server"] = slave["server"]
                  target_slave["id"] = id
                  target_slave["shell"] = shell_name
                  target_slave["left_resource"] = report
                  target_slave["board"] = slave["board"]
                  target_slave["device"] = slave["device"]
                end
              end
            }
            if(target_slave.has_key?"left_resource")
              ip["determined"] = "#{target_slave["server"]}-1"
              ip["determined_type"] = "0: spare server"
              ip["shell"] = target_slave["shell"]
              ip["device"] = target_slave["device"]
              slaves[target_slave["id"]]["resource"] = target_slave["left_resource"]
              slaves[target_slave["id"]]["base-shell"] = target_slave["shell"]
              slaves[target_slave["id"]]["shell"] = Hash.new
              slaves[target_slave["id"]]["shell"]["name"] = target_slave["shell"]
              slaves[target_slave["id"]]["shell"]["tag"] = SourcesManager.get_tag_by_name(target_slave["shell"])
              slaves[target_slave["id"]]["shell"]["hardware"] = Hash.new
              slaves[target_slave["id"]]["shell"]["hardware"]["board"] = target_slave["board"]
              slaves[target_slave["id"]]["shell"]["hardware"]["device"] = target_slave["device"]
              slaves[target_slave["id"]]["shell"]["compatible_shell"] = ""
              slaves[target_slave["id"]]["shell"]["conf"] = ""
              num_implemented_ip = num_implemented_ip + 1
            end
          }
          return true, ips if(ips.count == num_implemented_ip)

          #Second, find FPGAs with enough bandwidth & resource
          ips.each{|ip|
            next if(ip.has_key?"determined")
            target_slave = Hash.new
            #Find a slave that left min resource after implementing this IP
            slaves.each_with_index{|slave, id|
              next if !slave.has_key?"base-shell"

              shell = slave["base-shell"]

              next if (get_shell_max_port(shell) == get_server_enabled_ip_number(slave["server"], slaves, ips))

              ip_resource, shell = get_ip_resource(ip["name"], ip["tag"], shell, nil)
              next if ip_resource == nil
              result, report = implementable(slave["resource"], ip_resource, 1, 0)
              next if !result

              if((!target_slave.has_key?"left_resource") || compare_resource(report, target_slave["left_resource"]))
                target_slave["server"] = slave["server"]
                target_slave["id"] = id
                target_slave["shell"] = shell
                target_slave["left_resource"] = report
                target_slave["device"] = slave["device"]
              end
            }

            if(target_slave.has_key?"left_resource")
      	      target_ip = 1
      	      slaves[target_slave["id"]]["ip"].each{|key,ip|
      		    break if ip["enable"] == 0
      	        target_ip = target_ip + 1
      	      }
              ip["determined"] = "#{target_slave["server"]}:#{target_ip}"
              ip["determined_type"] = "1: server with enough bandwidth"
              ip["shell"] = target_slave["shell"]
              ip["device"] = target_slave["device"]
              slaves[target_slave["id"]]["resource"] = Hash.new
              slaves[target_slave["id"]]["resource"]["1"] = Hash.new
              target_slave["left_resource"].each{|key, value|
                next if(key == "Bandwidth")
                slaves[target_slave["id"]]["resource"]["1"][key] = value
              }
              slaves[target_slave["id"]]["Bandwidth"] = target_slave["left_resource"]["Bandwidth"]
              num_implemented_ip = num_implemented_ip + 1
            end
          }
          return true, ips  if(ips.count == num_implemented_ip)

          #Third, find FPGAs with enough esource
          ips.each{|ip|
            next if(ip.has_key?"determined")
            target_slave = Hash.new
            #Find a slave that left min resource after implementing this IP
            slaves.each_with_index{|slave, id|
              next if !slave.has_key?"base-shell"

              shell = slave["base-shell"]
              next if (get_shell_max_port(shell) == get_server_enabled_ip_number(slave["server"], slaves, ips))

              ip_resource, shell = get_ip_resource(ip["name"], ip["tag"], shell, nil)
              next if ip_resource == nil
              result, report = implementable(slave["resource"], ip_resource, 1, 1)
              next if !result

              if((!target_slave.has_key?"left_resource") || compare_resource(report, target_slave["left_resource"]))
                target_slave["server"] = slave["server"]
                target_slave["id"] = id
                target_slave["shell"] = shell
                target_slave["left_resource"] = report
                target_slave["device"] = slave["device"]
              end
            }

            if(target_slave.has_key?"left_resource")
	            target_ip = 1
              slaves[target_slave["id"]]["ip"].each{|key, ip|
                break if ip["enable"] == 0
                target_ip = target_ip + 1
              }
              ip["determined"] = "#{target_slave["server"]}:#{target_ip}"
              ip["determined_type"] = "2: server without enough bandwidth"
              ip["shell"] = target_slave["shell"]
              ip["device"] = target_slave["device"]
              slaves[target_slave["id"]]["resource"] = Hash.new
              slaves[target_slave["id"]]["resource"]["1"] = Hash.new
              target_slave["left_resource"].each{|key, value|
                next if(key == "Bandwidth")
                slaves[target_slave["id"]]["resource"]["1"][key] = value
              }
              slaves[target_slave["id"]]["Bandwidth"] = target_slave["left_resource"]["Bandwidth"]
              num_implemented_ip = num_implemented_ip + 1
            end
          }

          if(ips.count > num_implemented_ip)
            UI.puts "Scheduling failed. No enough available resources on cluster."
            return false, ips
          else
            return true, ips
          end
        end

        def get_shell_resource(name)
          tag = SourcesManager.get_tag_by_name(name)
          require 'json'
          Find.find(File.expand_path("#{Dir.home}/.hcode/repos/")) do |path|
            if path =~ /.*#{name}\/#{tag}\/hcode\.spec$/
              json = File.read(path)
              spec = JSON.parse(json)
              res = spec["resource"]
              res["Bandwidth"] = spec["interface"]["host"]["bandwidth"]
              return res
            end
          end          
        end

        def get_ip_resource(name, tag, shell, board)
          require 'json'
          Find.find(File.expand_path("#{Dir.home}/.hcode/repos/")) do |path|
            if path =~ /.*#{name}\/#{tag}\/hcode\.spec$/
              json = File.read(path)
              spec = JSON.parse(json)
              res = nil
              if((shell) && (spec["shell"].has_key?shell))
                res = spec["shell"][shell]["property"]["resource"]
                res["Bandwidth"] = spec["shell"][shell]["property"]["throughput"]
              else
                spec["shell"].each{|k,v|
                  if(get_board_by_shell(k) == board)
                    res = v["property"]["resource"]
                    res["Bandwidth"] = v["property"]["throughput"]  
                    shell = k
                  end
                }  
              end
              return res, shell
            end
          end
        end

        def get_board_by_shell(shell_name)
          begin
              set = SourcesManager.fuzzy_search_by_name(shell_name)
              json = File.read(set.highest_version_spec_path.to_s)
              spec = JSON.parse(json)
              return spec["hardware"]["board"]    
            rescue => e
              #UI.puts "Error: Can not find repo for #{shell_name}.".red
            nil             
            end    
        end

        def compare_resource(a, b)
          if((a["LUT"] < b["LUT"]))
            return (@constrain == 0 ? true : false)
          else
            return (@constrain == 0 ? false : true)
          end
        end

        def implementable(shell_resource, ip_resource, ip_quantity, type)
          resource_used = Hash.new
          report_utilization = Hash.new

          #accumulate resource used by IPs
          ip_resource.each{|key,value|
            if(resource_used.has_key?key)
              resource_used[key] = resource_used[key] + value
            else
              resource_used[key] = value
            end
          }

          report_utilization["Bandwidth"] = shell_resource["Bandwidth"].to_f - resource_used["Bandwidth"].to_f * ip_quantity.to_f

          #calculate utilization rate
          shell_resource.each{|region_id,region_resource|
            next if(region_id == "Bandwidth")
            region_resource.each{|key, value|
              if(resource_used.has_key?key)
                report_utilization[key] = (value.to_f - resource_used[key].to_f * ip_quantity.to_f).round(2)
              else
                report_utilization[key] = value.to_f
              end
            }
          }

          report_utilization.each{|key,value|
            if((key != "Bandwidth") && (value < 0))
              return false
            end
          }

          if ((type == 0) && (report_utilization["Bandwidth"] < 0))
            return false
          end
 
          return true, report_utilization
        end

        def get_server_enabled_ip_number(server_name, slave_list, ip_list)
          ip_num = 0
          #Current IPs
          slave_list.each{|server|
            if (server["server"] == server_name)
              next if server["ip"] == nil
              server["ip"].each{|k,ip|
                ip_num = ip_num + 1  if (ip["enable"] == 1)
              }
            end
          }
          #Scheduled IPs
          ip_list.each{|ip|
            ip_num = ip_num + 1 if (ip["determined"] && ip["determined"].split(":")[0] == server_name)
          }
          return ip_num
        end

        def get_shell_max_port(shell_name)
          shells = SourcesManager.get_compatible_shell(shell_name)
          max_port = 0
          shells.each{|k,v|
            n_port = v.gsub("ch version.","").to_i
            max_port = n_port if max_port < n_port
          }
          return max_port
        end
      end
    end
  end
end
