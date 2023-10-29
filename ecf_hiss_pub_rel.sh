#!/bin/bash
# Hiss Active Recon Scanner - David Kuszmar - 2023
# v 2.0
# Hiss is meant to quickly assess a large block of infospace. It is not stealthy.
# Some modifications have been made to the scan to protect the user from infoleak,
# but this is not a scan that will go unnoticed. Abide by all applicable laws
# and permissions.

# Display banner
function display_banner() {
echo -e "\e[44m\e[97m########################################\e[0m"
echo -e "\e[44m\e[97m#     Hiss Scan   -   empty_circle     #\e[0m"
echo -e "\e[44m\e[97m#         Hiss is not stealth          #\e[0m"
echo -e "\e[44m\e[97m#                                      #\e[0m"
echo -e "\e[44m\e[97m#                                      #\e[0m"
echo -e "\e[44m\e[97m########################################\e[0m"
}

function generate_random_mac() {
local oui_list=("00:0C:29" "00:50:56" "00:1C:42" "00:1D:0F" "00:1E:68" "00:1F:29" "00:21:5A" "00:25:B5" "00:26:5E" "00:50:43" "00:26:C7" "00:16:3E" "00:28:45" "00:2A:FA" "00:2B:0E")
local oui=${oui_list[$((RANDOM % ${#oui_list[@]}))]}
local nic=$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/.$//')
echo "$oui:$nic"
}

function generate_random_dns_servers() {
local dns_servers=("208.67.222.222" "208.67.220.220" "8.8.8.8" "8.8.4.4" "9.9.9.9" "149.112.112.112" "1.1.1.1" "1.0.0.1" "64.6.64.6" "64.6.65.6" "185.228.168.168" "185.228.169.168" "156.154.70.1" "156.154.71.1" "84.200.69.80" "84.200.70.40")
local random_dns_servers=($(shuf -e "${dns_servers[@]}"))
local random_dns_servers_list=$(IFS=,; echo "${random_dns_servers[*]}")
echo "$random_dns_servers_list"
}

# Usage function for user information
function usage() {
echo "Usage: $0 -t <target range> -c <timing number> -o <output file>"
echo ""
echo "  -t  target range in CIDR notation (required)"
echo "  -o  output file (required)"
echo "  -c  timing number (required)"
echo ""
exit 1
}

# Function to shuffle and select 3-7 IPs from a given pool
function shuffle_ips() {
  local pool=("$@")
  local count=$((3 + RANDOM % 5)) # Select random count between 3 and 7
  local selected_ips=$(shuf -e "${pool[@]}" | head -n $count | tr '\n' ' ')
  echo "$selected_ips"
}

#Decoy IPs are currently set to BRICKS nations
turkish_ips=("78.186.191.40" "88.233.44.203" "81.213.142.156" "95.9.128.180")
chinese_ips=("58.19.24.13" "123.125.115.110" "220.181.108.77" "120.92.4.1")
russian_ips=("92.63.64.0" "92.63.64.12" "92.63.64.113" "92.63.65.10")
south_african_ips=("41.13.112.152" "105.4.8.155" "197.83.240.85" "196.38.40.179")
north_korea_ips=("175.45.176.1" "175.45.176.3" "175.45.176.85" "175.45.176.99")
india_ips=("106.51.56.23" "182.76.144.66" "106.51.56.23" "117.195.40.6")

# Shuffle and select IPs from each pool
selected_turkish_ips=$(shuffle_ips "${turkish_ips[@]}")
selected_chinese_ips=$(shuffle_ips "${chinese_ips[@]}")
selected_russian_ips=$(shuffle_ips "${russian_ips[@]}")
selected_south_african_ips=$(shuffle_ips "${south_african_ips[@]}")
selected_north_korea_ips=$(shuffle_ips "${north_korea_ips[@]}")
selected_india_ips=$(shuffle_ips "${india_ips[@]}")

# Convert selected IPs to comma-separated strings
selected_turkish_ips=$(echo "$selected_turkish_ips" | tr ' ' ',')
selected_chinese_ips=$(echo "$selected_chinese_ips" | tr ' ' ',')
selected_russian_ips=$(echo "$selected_russian_ips" | tr ' ' ',')
selected_south_african_ips=$(echo "$selected_south_african_ips" | tr ' ' ',')
selected_north_korea_ips=$(echo "$selected_north_korea_ips" | tr ' ' ',')
selected_india_ips=$(echo "$selected_india_ips" | tr ' ' ',')

combined_ips=""
separator=""

# A list of all the selected IPs for easy looping
all_selected=("$selected_turkish_ips" "$selected_chinese_ips" "$selected_russian_ips" "$selected_south_african_ips" "$selected_north_korea_ips" "$selected_india_ips")

# Loop through and append to the combined_ips string, with appropriate comma separators
for selected in "${all_selected[@]}"; do
  if [[ ! -z "$selected" ]]; then
    combined_ips="${combined_ips:+$combined_ips,}${selected}"
  fi
done

combined_ips=$(echo "$combined_ips" | tr -s ',' | sed 's/^,//' | sed 's/,$//')

# Insert 'ME' randomly
num_elements=$(echo "$combined_ips" | awk -F ',' '{print NF}')
if [ "$num_elements" -eq 0 ]; then
  # If no elements, just set the decoy as ME
  combined_ips_with_me="ME"
else
  position=$((RANDOM % num_elements))
  if [ "$position" -eq 0 ]; then
    combined_ips_with_me="ME,$combined_ips"
  else
    pre_me=$(echo "$combined_ips" | cut -d ',' -f 1-"$position")
    post_me=$(echo "$combined_ips" | cut -d ',' -f $((position + 1))-)
    combined_ips_with_me="${pre_me},ME,${post_me}"
  fi
fi

combined_ips=${combined_ips%,}

if [ -z "$combined_ips" ]; then
  echo "Error: combined_ips is empty. Exiting."
  exit 1
fi

# Variables
tgtrange=""
output=""
c=""

# Process command-line options
while getopts "t:o:c:" opt; do
case $opt in
t) tgtrange="$OPTARG" ;;
o) output="$OPTARG" ;;
c) c="$OPTARG" ;;
\?) usage ;;
esac
done

# Rep
display_banner

# Error handling
if [[ -z "$tgtrange" ]] || [[ -z "$output" ]]; then
echo "Error: Missing required options"
usage
fi

touch $output_file 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Invalid output file path or permissions."
  exit 1
fi

# Create nmap command with options
mac=$(generate_random_mac)

# Load a list of random DNS servers
random_dns_servers=$(generate_random_dns_servers)

nmap_command="nmap -n -PE -PP -PS21,22,23,25,80,113,443,31339 -PA80,113,443,10042 -PU40125,161 --source-port 53 --randomize-hosts -T$c --max-retries 2 --spoof-mac $mac --dns-servers $random_dns_servers --data-length 651 -D 190.173.78.36,186.18.16.7,ME,190.175.27.84 $tgtrange -oG $output"

# Execute nmap command
eval $nmap_command

# Confirm the scan has completed
echo "Completed. Check your output location: $output"
