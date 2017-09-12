require 'jimson'
require 'find'
require 'terminal-table'

module Pod
  class Command
    class Cluster < Command
      #-----------------------------------------------------------------------#
      #Install a IP
      #-----------------------------------------------------------------------#
      class Status < Cluster
        extend Jimson::Handler

        self.summary = 'Report the status of cluster.'

        self.description = <<-DESC
          Report the status of cluster.
        DESC

        def initialize(argv)
          super
        end

        def run
          require 'json'
          @slaves_file = "#{Dir.home}/.hcode/slaves"
          if !File.exist?(@slaves_file)
            UI.puts "Slave list (~/.hcode/slaves) does not exist, please make one.".red
            exit
          end
          slaves = File.readlines(@slaves_file)

          slaves_status = Hash.new
          #Iterate all slaves
          slaves.each{ |slave|
            result_ips = ""
            slave_name = slave.gsub("\n","")
            url = "http://#{slave_name}:8999"
            client = Jimson::Client.new(url) 
            begin
              slave_conf = JSON.parse(client.get_slave_conf)
              UI.puts "[Slave: #{slave_name}]".on_green.white.bold
            rescue => e
              UI.puts "[Slave: #{slave_name}]".on_red.white.bold
              puts e.message
              puts
              next
            end

            #Iterate FPGAs on target slave
            slave_fpgas = slave_conf["FPGA"]
            slave_fpgas.each{ |fpga_key,fpga|
              UI.puts "[FPGA-#{fpga_key}: #{fpga["board"]}]".green
              slaves_status["#{slave_name}-#{fpga_key}"] = Hash.new
              slaves_status["#{slave_name}-#{fpga_key}"]["board"] = fpga["board"]
              slaves_status["#{slave_name}-#{fpga_key}"]["device"] = fpga["device"]  
              slaves_status["#{slave_name}-#{fpga_key}"]["ip"] = fpga["ip"]  
              slaves_status["#{slave_name}-#{fpga_key}"]["shell"] = fpga["shell"]  

              if(fpga.has_key?"ip")
                ips = fpga["ip"]
                #Get shell info on target FPGA
                tmp_shell = fpga["shell"]
                if((tmp_shell["compatible_shell"] != nil) && (tmp_shell["compatible_shell"] != ""))
                  shell_for_ip = tmp_shell["compatible_shell"]
                else
                  shell_for_ip = tmp_shell["name"]
                end
                resource_shell = get_shell_resource(tmp_shell["name"], tmp_shell["tag"])
                result_ips = result_ips + "* [Shell] #{tmp_shell["name"]}:#{tmp_shell["tag"]}\t#{tmp_shell["ip_conf"]}\n"
                slaves_status["#{slave_name}-#{fpga_key}"]["base-shell"] = shell_for_ip

                #Get IPs info on target FPGA
                resource_ips = Hash.new
                ips.each{ |ip_key,ip|
                  ip_status = ip["enable"] == 1 ? "Enable" : "Disable"
                    if (ip["enable"] == 1)
                      result_ips = result_ips + "* [IP-#{ip_key}] #{ip["name"]}:#{ip["tag"]}\t#{ip_status}\n"
                      result_ips = result_ips + "         Parameters:#{ip["ip_conf"]}\n"
                      result_ips = result_ips + "         Config:#{ip["conf_user"]}@#{ip["conf_date"]}\t\tCreate:#{ip["make_user"]}@#{ip["make_date"]}\n"
                      resource_ips[ip_key] = ip["resource"]
                    else
                       result_ips = result_ips + "* [IP-#{ip_key}] #{ip["name"]}:#{ip["tag"]}\t#{ip_status}\t(#{ip["ip_conf"]})\n".red   
                       result_ips = result_ips + "         Parameters:#{ip["ip_conf"]}\n".red
                       result_ips = result_ips + "         Config:#{ip["conf_user"]}@#{ip["conf_date"]}\t\tCreate:#{ip["make_user"]}@#{ip["make_date"]}\n".red              
                    end
                }
                
                UI.puts result_ips
                report_utilization = get_utilization(resource_ips, resource_shell, "used-percentage")
                slaves_status["#{slave_name}-#{fpga_key}"]["resource"] = get_utilization(resource_ips, resource_shell, "left-number")
                print_utilization(report_utilization)
                UI.puts
              else
                UI.puts "Unused"
              end
              UI.puts
            }
          }

          slaves_status_file = "#{Dir.home}/.hcode/slaves_status.log"
          File.open(slaves_status_file, 'w') do |file|
            json_str = JSON.pretty_generate(slaves_status)
            str = file.write(json_str)
          end
        end

        def get_shell_resource(name, tag)
          Find.find(File.expand_path("#{Dir.home}/.hcode/repos/")) do |path|
            if path =~ /.*#{name}\/#{tag}\/hcode\.spec$/
              json = File.read(path)
              spec = JSON.parse(json)
      	      res = spec["resource"]
              res.each{|id, resource|
      	       resource = spec["interface"]["host"]["bandwidth"]
              }
              return res
            end
          end
        end

        def get_utilization(resource_ips, resource_shell_all, type)
          report_utilizations = Array.new

          resource_shell_all.each{|id, resource_shell|
            resource_used = Hash.new
            report_utilization = Hash.new

            if(resource_shell_all.count == 1)
              #accumulate resource used by IPs
              resource_ips.each{|ip_key,ip|
                ip.each{|key,value|
                  if(resource_used.has_key?key)
                    resource_used[key] = resource_used[key] + value.to_i
                  else
                    resource_used[key] = value.to_i
                  end
                }
              }
            else
              if resource_ips.has_key?id
                ip = resource_ips[id]
                ip.each{|key,value|
                  if(resource_used.has_key?key)
                    resource_used[key] = resource_used[key] + value.to_i
                  else
                    resource_used[key] = value.to_i
                  end
                }
              end              
            end

            #calculate utilization rate
            resource_shell.each{|key,value|
              if(resource_used.has_key?key)
                if(type == "used-percentage")
                  report_utilization[key] = "#{((resource_used[key].to_f/value.to_f) * 100).round(2).to_s}%"
                elsif(type == "used-number")
                  report_utilization[key] = "#{resource_used[key].to_s}"
                elsif(type == "left-percentage")
                  report_utilization[key] = "#{((1 - resource_used[key].to_f/value.to_f) * 100).round(2).to_s}%"
                elsif(type == "left-number")
                  report_utilization[key] = "#{(value.to_f - resource_used[key].to_f).round(2).to_s}"
                end
              else
                if(type == "used-percentage")
                  report_utilization[key] = "0%"
                elsif(type == "used-number")
                  report_utilization[key] = "0"
                elsif(type == "left-percentage")
                  report_utilization[key] = "100%"
                elsif(type == "left-number")
                  report_utilization[key] = "#{value}"
                end
              end
            }

            report_utilizations.push report_utilization
          }
          return report_utilizations
        end

        def print_utilization(report_utilizations)
          #print output
          header = Array.new
          header.push ""

          report_utilizations[0].each{|key,value|
            header.push(key)
          }

          rows = Array.new
          report_utilizations.each_with_index{|report_utilization,id|
            row = Array.new
            row.push("Region #{id+1}")
            report_utilization.each{|key,value|
              row.push(value)
            }
            rows.push row
          }

          table = Terminal::Table.new :headings => header, :rows => rows
          UI.puts table
        end

      end
    end
  end
end
