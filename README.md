Octoprint Printer Connection Script
Written by RAIDLime, Dec 2024

Problem
------------------------

I had a need to downsize/redeploy some of my Pi hardware to other projects and removed the dedicated Pis from my three printers. These Pis formerly powered on with the printers and OctoPrint was set on each one to automatically connect to their respective printers on startup, meaning I could power on a printer and immediately send a job to it. 

I now have a single Raspberry Pi 4/4GB with 3 instances of Octoprint running on it, deployed on Pi OS Lite (Debian) using the scripts over at paukstelis/octoprint_deploy here on GitHub. This setup works well overall and runs my three printers simultaneously without any issues.

That said, my printers are always in various states of use; sometimes they are printing, sometimes they sit idle, or sometimes some of them are powered off for one reason or another. This led to a sort of "first world problem" where when I now power on a printer, I have to open up its Octoprint instance and connect it to the printer before I can start any jobs, adding an extra step for me to make a printer ready.

Solution
------------------------

Using the OctoPrint APIs and some scripting along with a cron job, I have now automated the extra step of connecting my printers when powered on. 

This script detects printer status and will reconnect a disconnected printer if the preferred port is available and no errors are present. I then created a cron job tied to this script that automatically runs it every minute against all my printers.

Requires curl.

Usage:
`# bash octoprint-connect.sh {instance-ip} {api-key} [override]`

Include the port number in the IP address if required (e.g. for octoprint-deploy instances - "x.x.x.x:5000")

The script will NOT work if the printer was brought offline due to an error (e.g. firmware reset due to thermal runaway, motion failure, probe failure, and other causes). This is by design as a safety measure, and I built this script with automation in mind.

Include "override" at the end of the command if you want to establish a connection anyways (e.g. if you fixed the error and want to force this script to establish the connection).

------------------------

Disclaimer: 									       
										       
Implementation of this script assumes the user implementing it is proficient with OctoPrint's functionaity and general Linux use, and is able to deploy the script with a full understanding of its function and risk.			       
										       
This is to say;								       
										       
BY USING THIS SCRIPT YOU PROCEED AT YOUR OWN RISK.				       
There may be errors or omissions that could cause damage to your systems or data. Proceed with appropriate caution.						       
										       
The script author takes no responsibility for any damages, incidental or otherwise.  
										       
Don't sue me please.								       
										       
------------------------

--- INSTRUCTIONS ---
---------------------------------------------

Get an Application Key
------------------------

First, create a new Application Key in OctoPrint for this script:

   Settings / Application Keys / Manually generate an application key

Name it whatever you'd like, then click "Generate". Record the long alphanumeric API key displayed in the resulting window.

Install the Script
------------------------

Put this script somewhere where you can find it (e.g. your home directory), and make it executable:

# chmod +x octoprint-connect.sh

If you do not intend on setting this script up to be automated with cron, you're done and the script is ready to use.

------------------------
Using the Script
------------------------

Run the script and insert the IP address of your OctoPrint instance (including port number if your setup requires it) as well as the API key you just generated.

Example:

# bash octoprint-connect.sh 192.168.1.99:5000 B1gL0n6Ap1k3Yg03sh3r3

Running this will run some checks and trigger one of the following outcomes:
- If OctoPrint is unreachable, it tells you with a reason code.
- If OctoPrint is reachable but the API key is invalid, it tells you.
- If OctoPrint is reachable and the API key is valid:
   - If the printer is connected, it tells you and does nothing else.
   - If the printer is not connected, it will check if OctoPrint has any registered errors
      - If an error is present, it will tell you the error it found and do nothing else.
      - If no error is present, or if there is an error and you included "override" at the end of your command, the script will send a connection command to OctoPrint then report back on connection status. All preferred port/speed settings are assumed. 
      
------------------------
Automating for auto-connections
------------------------

Create another file in the same location as the script named "octo-apis". In this file, put the IP address (+ port if needed) and the API key on the same line separated by a comma. 

Example:

192.168.1.99:5000,B1gL0n6Ap1k3Yg03sh3r3

If you have multiple printers and OctoPrint instances, create separate lines for each.

Example:

192.168.1.99:5000,B1gL0n6Ap1k3Yg03sh3r3
192.168.1.99:5001,an0th3rB1gL0n6Ap1k3Y1
192.168.1.99:5002,y37an0th3rB1gL0n6Ap1k

With this set up, we now need to create a new cron job. Launch the cron editor with:

# crontab -e

Insert the following into crontab (the whole thing is one line), updating the full paths to your script and octo-apis file:

* * * * * for i in `cat /path/to/octo-apis`; do ip=$(echo $i | awk -F, '{print $1}'); api=$(echo $i | awk -F, '{print $2}'); bash /path/to/octoprint-connect.sh $ip $api > /dev/null; done

As written, every minute, this job will run this script against the printers in the octo-apis file, automatically establishing a connection to printers you have just powered on.

DO NOT INCLUDE THE OVERRIDE FLAG IN ANY AUTOMATION UNLESS YOU WANT TO RISK A BAD TIME. Valuable error information can be harder to find and/or lost if this automation is allowed to run on a printer that's been offlined from an error.
