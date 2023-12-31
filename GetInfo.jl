#This file has definied all the functions necessary to write all necessary info about the local network into some files and display them.
using Sockets

const my_ip = getipaddr()
print("Machine ip is $(my_ip)\n")

#Get default route using the 'ip route' command.
function default_route_gen!()
	open("default_route.txt","w") do f
		redirect_stdio(stdout=f) do # redirect STDOUT to file and capture output of command into file.
			run(`ip route`) #OS specific command.
		end
	end
end

#Pull out the default route and subnet id from the file generated by the above function.
function get_default_route()
	ip,subnet_id = open("default_route.txt") do f
		a = readlines(f)
		ip =IPv4( split(a[1]," ")[3]) 
		subnet_id = split(a[2]," ")[1]
		return ip,subnet_id
	end
	return ip,subnet_id
end


#Get all available hosts on the network by doing an NMAP scan over the network and write into a file.
function hosts_gen!(subnet_id::AbstractString)
	open("hosts.txt","w") do f
			redirect_stdio(stdout = f) do
				run(`nmap -sn $(subnet_id)`)
			end
	end
end

#Get all devices from file created by above function and convert their ip addrs into an IPv4 object, then return the array of available ips on the subnet.
function get_hosts(my_ip::IPv4,default_gateway::IPv4)
	addrs = open("hosts.txt") do f 
		text = readlines(f)
		i = 2
		addrs = []
		while true
			try
				addr = IPv4(split(text[i]," ")[end])
				!(isequal(addr,my_ip)||isequal(addr,default_gateway)) && push!(addrs,addr)
			catch e
				if isa(e,BoundsError)
					return addrs
				end
			end
			i+=2
		end
	end
	#run(`rm hosts.txt`)
end

#Use arp_table_gen! and get_hosts_arp if windows firewall blocks the icmp request messages used by nmap to discover hosts on the network.
function arp_table_gen!()
	open("arp.txt","w") do f
		redirect_stdio(stdout=f) do
			run(`cat /proc/net/arp`)  #This command is UNIX specific.
		end
	end
end

function get_hosts_arp(my_ip::IPv4,default_gateway::IPv4) 
	addrs = open("arp.txt") do f
		addrs = []
		readline(f)
		while !eof(f)
			mark(f)
			ip_ad = IPv4(readuntil(f," "))
			reset(f)
			skip(f,41)
			mac_addr = readuntil(f," ")
			!(isequal(ip_ad,default_gateway) || isequal(mac_addr,"00:00:00:00:00:00")) && push!(addrs,ip_ad) 
			readline(f)
		end
		return addrs
	end
	#run(`rm arp.txt`)
	return addrs
end

function get_open_ports(addrs,port)   #Return all hosts on the LAN who are listening on port = 𝐩𝐨𝐫𝐭	 
	hosts = Dict()
	i = 1
	for addr in addrs
		open("temp.txt","w") do f
			redirect_stdio(stdout = f) do
				run(`nmap -Pn -p$(port) $(addr)`)
			end
		end
		
		status = open("temp.txt") do f
			readuntil(f,"$(port)/tcp")
			skip(f,1)
			readuntil(f," ")
		end
		isequal(status,"open") && (hosts[i] = addr;i+=1)	
	end
	run(`rm temp.txt`)
	return hosts
end
