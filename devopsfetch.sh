#!/bin/bash

# Function to display help
display_help() {
	echo "Usage: devopsfetch [OPTION]"
	echo "Retrieve and display system information for DevOps purposes."
	echo
	echo "Options:"
	echo "  -p, --port [PORT]    Display active ports or specific port info"
	echo "  -d, --docker [NAME]  List Docker images/containers or specific container info"
	echo "  -n, --nginx [DOMAIN] Display Nginx domains or specific domain config"
	echo "  -u, --users [USER]   List users and last login or specific user info"
	echo "  -t, --time RANGE     Display activities within a time range (e.g., '1 hour ago')"
	echo "  -h, --help           Display this help message"
}

# Function to display ports
display_ports() {
	echo -e "PORT\tSERVICE"
	if [ -z "$1" ]; then
		ss -tuln | awk 'NR>1 {split($5, a, ":"); print a[length(a)]}' | sort -u | while read port; do
			lsof_output=$(lsof -i :$port -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {print $3, $9, $1}' | awk -v p=$port '{split($2, a, ":"); if (a[length(a)] == p) print $1, p, $3}' | sort -u)
			if [ -z "$lsof_output" ]; then
				netstat_output=$(netstat -tuln | awk -v port=":$port" '$0 ~ port {print $1, $4, $7}' | awk '{split($2, a, ":"); print $3, a[length(a)], $1}' | sort -u)
				echo "$netstat_output"
			else
				echo "$lsof_output"
			fi
		done
	else
		lsof_output=$(lsof -i :$1 -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {print $3, $9, $1}' | awk -v p=$1 '{split($2, a, ":"); if (a[length(a)] == p) print $1, p, $3}' | sort -u)
		if [ -z "$lsof_output" ]; then
			netstat_output=$(netstat -tuln | awk -v port=":$1" '$0 ~ port {print $1, $4, $7}' | awk '{split($2, a, ":"); print $3, a[length(a)], $1}' | sort -u)
			echo "$netstat_output"
		else
			echo "$lsof_output"
		fi
	fi | column -t
}

# Function to display Docker info
display_docker() {
	if [ -z "$1" ]; then
		docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.ID}}"
	else
		docker inspect "$1" | jq '.[0] | {Name: .Name, State: .State.Status, Image: .Config.Image, ID: .Id}' | column -t
	fi
}

# Function to display Nginx info
display_nginx() {
	if [ -z "$1" ]; then
		echo -e "DOMAIN\tPROXY\tCONFIGURATION\tCONFIG FILE"
		grep -R server_name /etc/nginx/sites-enabled/ | awk '{print $2 "\t" $3 "\t" $1 "\t" FILENAME}' | sed 's/;//' | column -t
	else
		grep -R -A 10 "server_name $1" /etc/nginx/sites-enabled/ | column -t
	fi
}

# Function to display user info
display_users() {
	if [ -z "$1" ]; then
		last | head -n 10 | column -t
	else
		last "$1" | head -n 5 | column -t
	fi
}

# Function to display logs within a time range
display_time_range() {
	if [ $# -eq 0 ]; then
		echo "Please specify a time range or date"
		return 1
	elif [ $# -eq 1 ]; then
		start_date=$(date -d "$1" +"%Y-%m-%d 00:00:00")
		end_date=$(date -d "$1 + 1 day" +"%Y-%m-%d 00:00:00")
	elif [ $# -eq 2 ]; then
		start_date=$(date -d "$1" +"%Y-%m-%d 00:00:00")
		end_date=$(date -d "$2 + 1 day" +"%Y-%m-%d 00:00:00")
	else
		echo "Invalid number of arguments for time range"
		return 1
	fi

	journalctl --since "$start_date" --until "$end_date" | awk '{print NR, $0}' | column -t
}

# Main logic
case "$1" in
-p | --port)
	display_ports "$2"
	;;
-d | --docker)
	display_docker "$2"
	;;
-n | --nginx)
	display_nginx "$2"
	;;
-u | --users)
	display_users "$2"
	;;
-t | --time)
	shift
	display_time_range "$@"
	;;
-h | --help)
	display_help
	;;
*)
	echo "Invalid option. Use -h or --help for usage information."
	exit 1
	;;
esac
