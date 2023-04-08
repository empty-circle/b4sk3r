#!/bin/bash
# empty_circle - 2023
# B4sk34 Sc4nn3r is a stealthy recon scanner that seeks to automate target enumeration by vulnerable ports
# It takes a range of IPs in CIDR notation, scans them all, parses them into a list, then passes them to
# a final scanner that enumerates the services and runs safe script scans on the list of IPs.

# Da Banner. Da Bears. Da Bulls.
echo -e "\e[44m\e[97m########################################\e[0m"
echo -e "\e[44m\e[97m#    B4sk3r Sc4nn3r  -  empty_circle   #\e[0m"
echo -e "\e[44m\e[97m#        b4sk3r is cold-blooded        #\e[0m"
echo -e "\e[44m\e[97m#        this could take awhile        #\e[0m"
echo -e "\e[44m\e[97m#           150 hosts/30min            #\e[0m"
echo -e "\e[44m\e[97m########################################\e[0m"


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

# Firewall foxing with nmap
mac=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')

# Built-out nmap command
nmap_command="nmap -sS -Pn --source-port 53 --randomize-hosts --host-timeout 1250 -p21,22,23,25,53,80,110,113,143,443,1723,3389,8080 -T2 --max-retries 1 --spoof
-mac $mac --dns-servers 4.2.2.1,4.2.2.2 $ip $tgtrange -oG $output"

if [ -n "$verbose" ]; then
  nmap_command="$nmap_command -v"
fi

if [ -n "$fragment" ]; then
  nmap_command="$nmap_command -f"
fi

eval $nmap_command

# Completion confirm
echo "Completed phase one. Your output location: $output"

#lizard eye section - executes search for open ips and shunts them into a file

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

#basker tail section - rolls through the open_ips and runs scans on them.

while read ip; do
  nmap -sV -sC --spoof-mac $mac --source-port 53 -Pn -T3 "$ip" -oN basker-service.map
  if [ $? -ne 0 ]; then
    echo "Error scanning $ip" >> basker-service-errors.log
  fi
done < open_ips.txt

printf "Completed."
