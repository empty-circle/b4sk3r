#!/bin/bash
# empty_circle - 2023
# v2.1
# B4sk34 Sc4nn3r is a stealthy recon scanner that seeks to automate target enumeration by vulnerable ports.
# It takes a range of IPs in CIDR notation, scans them all, parses them into a list, then passes them to
# a final scanner that enumerates the services and runs safe script scans on the list of IPs.

function print_banner() {
  local banner="\e[44m\e[97m########################################\e[0m\n"
  banner+="\e[44m\e[97m#    B4sk3r Sc4nn3r  -  empty_circle   #\e[0m\n"
  banner+="\e[44m\e[97m#        b4sk3r is cold-blooded        #\e[0m\n"
  banner+="\e[44m\e[97m#        this could take awhile        #\e[0m\n"
  banner+="\e[44m\e[97m#           150 hosts/30min            #\e[0m\n"
  banner+="\e[44m\e[97m########################################\e[0m"
  echo -e "${banner}"
}

function generate_random_mac() {
  local oui_list=("00:0C:29" "00:50:56" "00:1C:42" "00:1D:0F" "00:1E:68" "00:1F:29" "00:21:5A" "00:25:B5" "00:26:5E" "00:50:43")
  local oui=${oui_list[$((RANDOM % ${#oui_list[@]}))]}
  local nic=$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/.$//')
  echo "$oui:$nic"
}

function generate_random_dns_servers() {
  local dns_servers=("208.67.222.222" "208.67.220.220" "8.8.8.8" "8.8.4.4" "9.9.9.9" "149.112.112.112" "1.1.1.1" "1.0.0.1" "64.6.64.6" "64.6.65.6")
  local random_dns_servers=($(shuf -e "${dns_servers[@]}"))
  local random_dns_servers_list=$(IFS=,; echo "${random_dns_servers[*]}")
  echo "$random_dns_servers_list"
}

function show_usage() {
  echo "Usage: $0 -t <target_range> -o <output_file> [-v|-f]"
  echo ""
  echo "  -t  target range in CIDR notation (required)"
  echo "  -o  output file (required)"
  echo "  -v  use verbose mode"
  echo "  -f  use fragmentation"
  echo ""
  exit 1
}

function lizard_eye(){
    output_file=$output_file
    declare -A open_ips_files

    open_ports=(21 22 23 80 110 125 443 3306 5060 8080)

    for port in "${open_ports[@]}"; do
        open_ips_files["$port"]="open_ips_port_$port.txt"
        touch "${open_ips_files["$port"]}"
    done

    while read -r line; do
        if [[ $line =~ ^Host:\ (.+)[[:space:]]\(\)[[:space:]]Ports:\ (.+) ]]; then
            ip=${BASH_REMATCH[1]}
            ports=${BASH_REMATCH[2]}

            for port in "${open_ports[@]}"; do
                if [[ $ports =~ $port/open ]]; then
                    echo "$ip" >> "${open_ips_files["$port"]}"
                fi
            done
        fi
    done < "$output_file"
}

function basker_tail(){
  echo "The final phase may take some additional time. Vulnerable targets are being examined more closely."
  echo "Keep in mind, mac spoofing, dns randomization, and other obfuscation methods have no effect"
  echo "on service and script scans due to their intrinsic nature."

  while read -r ip; do
    nmap -sV -sC -T3 --version-intensity 8 "$ip" -oA basker-service.map
    if [ $? -ne 0 ]; then
      echo "Error scanning $ip" >> basker-service-errors.log
    fi

  done < "open_ips.txt"
}

verbose=0
fragment=0
while getopts "t:o:vf" opt; do
  case $opt in
    t) target_range="$OPTARG"
    ;;
    o) output_file="$OPTARG"
    ;;
    v) verbose=1
    ;;
    f) fragment=1
    ;;
    \?) show_usage
    ;;
  esac
done

if [ -z "$target_range" ] || [ -z "$output_file" ]; then
  show_usage
fi

# Rep it
print_banner

# Load a MAC address for spoofing
mac=$(generate_random_mac)

# Load a list of random DNS servers
random_dns_servers=$(generate_random_dns_servers)

# Build nmap command
nmap_command="nmap -sS -Pn --source-port 53 --randomize-hosts -p21,22,23,25,53,80,110,113,143,443,1723,3389,8080 -T2 --max-retries 2 --spoof-mac $mac --dns-servers $random_dns_servers --data-length 731 -D 190.173.78.36,186.18.16.7,ME,190.175.27.84 $target_range -oG $output_file"

# Check if verbosity or frag are requested
if [ "$verbose" -eq 1 ]; then
  nmap_command="$nmap_command -v"
fi

if [ "$fragment" -eq 1 ]; then
  nmap_command="$nmap_command -f"
fi

# Initiate scan
eval $nmap_command

echo "Completed phase one. Your output location: $output_file"

# Call lizard eye
lizard_eye

echo "Completed phase two. Sorted lists created."

# Call basker tail - removed for now
# basker_tail

#echo "Phase three completed. Check your output files."
echo "Phase three skipped. Check your output files."
