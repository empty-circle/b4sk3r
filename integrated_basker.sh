#!/bin/bash
# empty_circle - 2023
# v1.6
# B4sk34 Sc4nn3r is a stealthy recon scanner that seeks to automate target enumeration by vulnerable ports
# It takes a range of IPs in CIDR notation, scans them all, parses them into a list, then passes them to
# a final scanner that enumerates the services and runs safe script scans on the list of IPs.

# Print banner
print_banner() {
  local banner="\e[44m\e[97m########################################\e[0m\n"
  banner+="\e[44m\e[97m#    B4sk3r Sc4nn3r  -  empty_circle   #\e[0m\n"
  banner+="\e[44m\e[97m#        b4sk3r is cold-blooded        #\e[0m\n"
  banner+="\e[44m\e[97m#        this could take awhile        #\e[0m\n"
  banner+="\e[44m\e[97m#           150 hosts/30min            #\e[0m\n"
  banner+="\e[44m\e[97m########################################\e[0m"
  echo -e "${banner}"
}

# Generate a random MAC address with a valid OUI
generate_random_mac() {
  local OUI_LIST=("00:0C:29" "00:50:56" "00:1C:42" "00:1D:0F" "00:1E:68" "00:1F:29" "00:21:5A" "00:25:B5" "00:26:5E" "00:50:43")
  local OUI=${OUI_LIST[$((RANDOM % ${#OUI_LIST[@]}))]}
  local NIC=$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/.$//')
  echo "$OUI:$NIC"
}

# Generate a random list of DNS servers
generate_random_dns_servers() {
  # List of popular public DNS server IPs
  local DNS_SERVERS=("208.67.222.222" "208.67.220.220" "8.8.8.8" "8.8.4.4" "9.9.9.9" "149.112.112.112" "1.1.1.1" "1.0.0.1" "64.6.64.6" "64.6.65.6")

  # Randomize the DNS_SERVERS array
  local RANDOM_DNS_SERVERS=($(shuf -e "${DNS_SERVERS[@]}"))

  # Join the randomized array with commas
  local RANDOM_DNS_SERVERS_LIST=$(IFS=,; echo "${RANDOM_DNS_SERVERS[*]}")

  echo "$RANDOM_DNS_SERVERS_LIST"
}

# Usage function call for user information
usage() {
  echo "Usage: $0 -t <target range> -o <output file> [-v|-f]"
  echo ""
  echo "  -t  target range in CIDR notation (required)"
  echo "  -o  output file (required)"
  echo "  -v  use verbose mode"
  echo "  -f  use fragmentation"
  echo ""
  exit 1
}

# CLI options
verbose=0
fragment=0
while getopts "t:o:vf" opt; do
  case $opt in
    t) tgtrange="$OPTARG"
    ;;
    o) output="$OPTARG"
    ;;
    v) verbose=1
    ;;
    f) fragment=1
    ;;
    \?) usage
    ;;
  esac
done

# Error handling
if [ -z "$tgtrange" ]; then
  echo "Error: Need target in CIDR notation"
  usage
fi

if [ -z "$output" ]; then
  echo "Error: Need output location or file"
  usage
fi

# Print banner
print_banner

# Load a mac address for spoofing
mac=$(generate_random_mac)

# Load a list of random DNS servers
random_dns_servers=$(generate_random_dns_servers)

# Built out nmap command
nmap_command="nmap -sS -Pn --source-port 53 --randomize-hosts --host-timeout 1250 -p21,22,23,25,53,80,110,113,143,443,1723,3389,8080 -T2 --max-retries 1 --spoof-mac $mac --dns-servers $random_dns_servers $tgtrange -oG $output"


if [ "$verbose" -eq 1 ]; then
  nmap_command="$nmap_command -v"
fi

if [ "$fragment" -eq 1 ]; then
  nmap_command="$nmap_command -f"
fi

eval $nmap_command

# Completion confirm
echo "Completed phase one. Your output location: $output"

# Lizard eye section - executes search for open IPs and shunts them into a file
file=$output
output_file="open_ips.txt"
touch "$output_file"
while read line; do
    if [[ $line =~ ^Host:\ (.+)[[:space:]]\(\)[[:space:]]Ports:\ (.+) ]]; then
        ip=${BASH_REMATCH[1]}
        ports=${BASH_REMATCH[2]}
        if [[ $ports =~ (21|22|23|80|110|125|443|3306|5060|8080)/open ]]; then
            echo "$ip" >> "$output_file"
        fi
    fi
done < "$file"

# Basker tail section - rolls through the open_ips and runs scans on them.
while read ip; do
  nmap -sV -sC --spoof-mac $mac --dns-servers $random_dns_servers --source-port 53 -Pn -T3 "$ip" -oA basker-service.map
  if [ $? -ne 0 ]; then
    echo "Error scanning $ip" >> basker-service-errors.log
  fi
done < open_ips.txt

printf "Completed."
