#!/bin/bash
#Turn on extglob for proper condition evaluations
shopt -s extglob
#stdout and stderr to be sent to the syslog1 original shell’s stderr (for debugging)
#exec 1> >(logger -s -t $(basename $0)) 2>&1

slack_hook="https://hooks.slack.com/services/RANDOMTOCKENFORYOURSLACKCHANNEL"

# This function collects information needed to create a DHCP reservation and add the switch to CMDB
function collect_inventory {
    #Collect MAC addresses of the MGMT interface
    MAC_eth0=`/bin/echo eth0 MAC: $(ip -o link show eth0 | cut -d " " -f 20)`
    #Collect MAC address of bridge interface (all SVIs will inherit this on VLAN aware bridge)
    MAC_bridge=`/bin/echo bridge MAC: $(ip -o link show bridge.555 | cut -d " " -f 19)`
    #Collect device's Serial Number
    SerialNumber=`/usr/cumulus/bin/decode-syseeprom | awk '/Serial Number/ {print "Serial Number: " $NF}'`
    #Collect device's Service Tag
    ServiceTag=`/usr/cumulus/bin/decode-syseeprom | awk '/Service Tag/ {print "Service Tag: " $NF}'`
    #Collect IP on bridge.555
    IP_address=`netshow interface | awk '/bridge.555/ {print "IP Address: " $NF}'`
}

# This function will install puppet-agent from cumulus linux specific puppet source
function install_puppet {
    # Test if package alredy downloaded to prevent multiple copies
    if [ ! -f /root/puppetlabs-release-pc1-cumulus.deb ]; then
      wget http://apt.puppetlabs.com/puppetlabs-release-pc1-cumulus.deb -O /root/puppetlabs-release-pc1-cumulus.deb
    fi
    # Install apt sources package
    dpkg -i /root/puppetlabs-release-pc1-cumulus.deb
    apt-get update
    apt-get install puppet-agent -y
}

# This function will check if puppet-agent package is installed and will call for installation of this package if it's not installed
function check_for_puppet {
    #Check if puppet is installed, install if not
    if [[ $(dpkg-query -W -f='${Status}' puppet-agent 2>/dev/null | grep -c "ok installed") = 0 ]];
      then
      install_puppet
    fi
}

# This function validates if curl is installed. Curl is needed to HTTP POST to Slack.
function check_for_curl {
    #Check if curl is installed, install if not
    if [[ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") = 0 ]];
      then
        apt-get update
        apt-get install curl -y
    fi
}

# Only proceed if network is up
if ping -c1 www.google.com &>/dev/null;
 then 	# Network is up
   if [[ $(hostname -s) =~ .*erase.* ]]; #Does hostname contain "erase"?
     then #Yes
       # Let's collect inventory info needed for checking into Slack
       collect_inventory
       former_hostname=`cat /etc/hostname`

       #Check if curl is installed, install if not
       check_for_curl

       # Post info into Slack channel
       curl -X POST -H "Content-type: application/json" --data '{"text":"Restoring to factory default `'"$former_hostname"'` switch with:\n'"$SerialNumber"'\n'"$ServiceTag"'\n'"$MAC_eth0"'\n'"$MAC_bridge"'"}' $slack_hook

       #Tell switch to uninstall OS on next boot and reload the switch
       /usr/cumulus/bin/cl-img-select -k -f
       shutdown -r now;

 elif [[ $(hostname -s) =~ .*-oob-.* || $(hostname -s) =~ .*-oob ]]; #No, check for "-oob" in name
   then #Yes
     #Check if hosname -s does not match /etc/hostname, remedy if not
     if ! [[ $(hostname -s) == `cat /etc/hostname` ]]; 
       then
         hostname > /etc/hostname;
         new_hostname=`hostname`
         collect_inventory
         curl -X POST -H "Content-type: application/json" --data '{"text":"Switch with *'"$ServiceTag"'* and *'"$MAC_eth0"'* just aquired new hostname '"$new_hostname"'"}' $slack_hook
       fi
       #Check if puppet is installed, install if not
       check_for_puppet

       #Check if puppet agent is running, start if not
       if [[ $(/opt/puppetlabs/bin/puppet resource service puppet | awk -F"'" '/ensure/ {print $2}') == "stopped" ]];
         then 
           /opt/puppetlabs/bin/puppet resource service puppet ensure=running
           # Check if the starting of the agent was successful. Report status to Slack.
           if [[ $(/opt/puppetlabs/bin/puppet resource service puppet | awk -F"'" '/ensure/ {print $2}') == "stopped" ]];
             then
               curl -X POST -H "Content-type: application/json" --data '{"text":"Node: '"$(hostname)"' Failed to set puppet service to *running*\n`Please check puppet agent on this node`"}' $slack_hook
             else
               curl -X POST -H "Content-type: application/json" --data '{"text":"Node: '"$(hostname)"' puppet service set to *running*"}' $slack_hook
             fi
         fi
       #Check if puppet agent is allowed to run, allow if not
       if [[ $(/opt/puppetlabs/bin/puppet resource service puppet | awk -F"'" '/enable/ {print $2}') == "false" ]];
         then 
           /opt/puppetlabs/bin/puppet resource service puppet enable=true
           # Check if enabling of the agent was successful. Report status to Slack.
           if [[ $(/opt/puppetlabs/bin/puppet resource service puppet | awk -F"'" '/enable/ {print $2}') == "false" ]];
             then 
               curl -X POST -H "Content-type: application/json" --data '{"text":"Node: '"$(hostname)"' Failed to set puppet service to *enabled*\n`Please check puppet agent on t    his node`"}' $slack_hook
             else
               curl -X POST -H "Content-type: application/json" --data '{"text":"Node: '"$(hostname)"' puppet service set to *enabled*"}' $slack_hook
           fi
         fi
       #puppet agent --fingerprint

 else #No "-oob-" or "erase" in hostname
   #Check if puppet is installed, install if not
#   check_for_puppet

   # Let's collect inventory info needed for checking into Slack
   collect_inventory

   #Check if curl is installed, install if not
   check_for_curl

   # Post info into Slack channel
   curl -X POST -H "Content-type: application/json" --data '{"text":"Awaiting DHCP reservation switch with:\n'"$SerialNumber"'\n'"$ServiceTag"'\n'"$MAC_eth0"'\n'"$MAC_bridge"'\n'"$IP_address"'"}' $slack_hook

   # bounce the dhclient on the SVI interface to check for a new DHCP lease info
   # dhclient -r bridge.555 && dhclient bridge.555
   systemctl reload-or-restart networking.service
   fi

 else	# Network is down		 	
   # bounce the dhclient on the SVI to try to recover connectivity
   # dhclient -r bridge.555 && dhclient bridge.555
   systemctl reload-or-restart networking.service 
   exit 0		
fi

