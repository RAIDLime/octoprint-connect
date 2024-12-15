#!/bin/bash

# Octoprint Printer Connection Script
# Written by RAIDLime, Dec 2024

# Detects printer status and will reconnect a disconnected printer if the preferred 
# port is available. Uses all auto or configured preferred settings.

# Requires curl.

# Usage:
# # bash octoprint-connect.sh {instance-ip} {api-key} [override]

# Include the port number in the IP address if required (e.g. for octoprint-deploy
# instances - "x.x.x.x:5000")

# The script will NOT work if the printer was brought offline due to an error (e.g. firmware reset due to 
# thermal runaway, motion failure, probe failure, and other causes). This is by design as a safety measure,
# and I built this script with automation in mind.

# Include "override" at the end of the command if you want to establish a connection anyways
# (e.g. if you fixed the error and want to force this script to establish the connection).

########################################################################################
#										       #
# Disclaimer: 									       #
#										       #
# Implementation of this script assumes the user implementing it is proficient         #
# with OctoPrint's functionaity and general Linux use, and is able to deploy the       #
# script with a full understanding of its function and risk.			       #
#										       #
# This is to say;								       #
#										       #
# BY USING THIS SCRIPT YOU PROCEED AT YOUR OWN RISK.				       #
# There may be errors or omissions that could cause damage to your systems or data.    #
# Proceed with appropriate caution.						       #
#										       #
# The script author takes no responsibility for any damages, incidental or otherwise.  #
#										       #
# Don't sue me please.								       #
#										       #
########################################################################################

# ------ Defining variables from command arguments ------

instance=$1
apikey=$2
override=$3

# ------ Sanity checking our arguments ------

if ! grep -q -oE '(\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}'  <<< "$instance"
	then
		echo "Invalid IP address."
		exit
fi

if [ -z $apikey ]
	then
		echo "No API key provided."
		exit
fi
		

# ------ Prereq - is curl installed? ------

if ! command -v curl 2>$1 >/dev/null
	then
		echo "curl is not installed. Please install it first then re-run this script."
		exit
fi

# ------ SCRIPT START ------

# Connect to the instance and react based on the HTTP code we get.
# - If forbidden (403) or can't be reached (000), print corresponding error
# - If we can connect to the instance (200), get the printer state
# - If the printer state is anything other than "Closed", give us that state description
# - If the printer state is "Closed", check for any errors and do not continue if there are any.
#    - We want to force the user to check/clear/resolve any errors and manually reconnect.
#    - We don't want an automated implementation of this script to reconnect to an errored printer. 
# - If no error is shown and preferred port is available, connect.

http_code=$(curl "$instance/api/connection" -H "x-api-key: $apikey" -H "Connection: close" -s -f -w %{http_code} -o /dev/null)

getstate () {
	fullstate=$(curl -s "$instance/api/connection" -H "x-api-key: $apikey" -H "Connection: close")
	abbvstate=$(echo "$fullstate" | grep state | grep -oE ': \".*\"$' | cut -c 4- | rev | cut -c 2- | rev)
}

if ((http_code == 000))
	then
		echo "Failed to connect to Octoprint instance. Is the IP correct? Is it available?"
		exit 1
elif ((http_code == 403))
	then
		echo "You do not have permission to access this instance. Is the API key correct?"
		exit 1
elif ((http_code == 200))
	then
		getstate
		if ! [ "$abbvstate" = "Closed" ]
			then 
				echo "Current state is:   $abbvstate"
				echo "No action taken."
				exit 0
			else
				errors=$(curl -s "$instance/api/printer/error" -H "x-api-key: $apikey" -H "Connection: close")
				if grep -q "consequence" <<< "$errors"
					then
						if ! grep -q "override" <<< "$override"
						then
						echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
						echo "PRINTER WENT OFFLINE DUE TO CRITICAL ERROR"
						echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
						echo ""
						echo "This script will not automatically reconnect to the printer as a safety measure." 
						echo "Resolve the error, reset the printer, and manually reconnect in the OctoPrint web interface."
						echo ""
						echo "Error info:"
						echo ""
						echo "$errors"
						exit 1
						elif grep -q "override" <<< "$override"
						then
						echo ""
						echo "Override flag provided while printer error present!" 
						echo "We are trusting any issues have been addressed and you know what you're doing..."
						echo ""
						fi
				fi
				portpref=$(echo "$fullstate" | grep portPreference | grep -oE ': \".*\",$' | cut -c 4- | rev | cut -c 3- | rev)
				if [[ $(echo "$fullstate" | grep "$portpref" | wc -l) -eq 2 ]]
					then
						curl "$instance/api/connection" -H "x-api-key: $apikey" -H "Content-Type: application/json" --data '{"command": "connect"}'
						sleep 2
						getstate
						echo "Connection request sent."
						echo "Current state is now:   $abbvstate"
						exit
					else
						echo "Printer disconnected and preferred port is unavailable."
						echo "Ensure the printer is powered on and physically connected."
						exit
				fi
		fi
	else
		echo "Don't know what to do. The instance returned HTTP code $http_code."
		exit 1
fi

# ------ SCRIPT END ------