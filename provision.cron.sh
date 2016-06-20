#!/bin/bash
#Turn on extglob for proper condition evaluations
shopt -s extglob
#stdout and stderr to be sent to the syslog1 original shell’s stderr (for debugging)
#exec 1> >(logger -s -t $(basename $0)) 2>&1

# Only proceed if network is up
if ping -c1 www.google.com &>/dev/null;
 then 	# Network is up
   if [[ $(hostname -s) =~ .*erase.* ]]; #Does hostname contain "erase"?
     then #Yes
       #Check if puppet is installed, install if not
       if [[ $(dpkg-query -W -f='${Status}' puppet 2>/dev/null | grep -c "ok installed") = 0 ]];
          then
            apt-get update
            apt-get install puppet -y
       fi
       #Collect MAC addresses of the MGMT interface
       MAC_eth0=`/bin/echo eth0 MAC: $(facter macaddress_eth0)`
       #Collect MAC address of bridge interface (all SVIs will inherit this on VLAN aware bridge)
       MAC_bridge=`/bin/echo bridge MAC: $(facter macaddress_bridge)`
       #Collect device's Serial Number
       SerialNumber=`/usr/cumulus/bin/decode-syseeprom | awk '/Serial Number/ {print "Serial Number: " $NF}'`
       #Collect device's Service Tag
       ServiceTag=`/usr/cumulus/bin/decode-syseeprom | awk '/Service Tag/ {print "Service Tag: " $NF}'`
       #Check if curl is installed, install if not
       if [[ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") = 0 ]];
          then
            apt-get update
            apt-get install curl -y
       fi
       curl -X POST -H "Content-type: application/json" --data '{"text":"Restoring to factory default switch with:\n'"$SerialNumber"'\n'"$ServiceTag"'\n'"$MAC_eth0"'\n'"$MAC_bridge"'"}' https://hooks.slack.com/services/adfadsfd/afdsfasdf/adfadsfasdfadsfa
       #Tell switch to uninstall OS on next boot and reload the switch
       /usr/cumulus/bin/cl-img-select -k -f
       shutdown -r now;
     elif [[ $(hostname -s) =~ .*-oob-.* ]]; #No, check for "-oob-" in name
       then #Yes
         #Check if hosname -s does not match /etc/hostname, remedy if not
         if ! [[ $(hostname -s) == `cat /etc/hostname` ]]; then hostname > /etc/hostname; fi
         #Check if puppet is installed, install if not
         if [[  $(dpkg-query -W -f='${Status}' puppet 2>/dev/null | grep -c "ok installed") = 0 ]];
	    then 
              apt-get update
              apt-get install puppet -y
         fi
#         #Check if puppet agent is allowed to run, allow if not
#         if [[ $(cat /etc/default/puppet | awk '/START/ {print $1}') == "START=no" ]];
#            then sed -i 's/START=no/START=yes/g' /etc/default/puppet
#            /usr/bin/puppet agent --enable
#         fi
         #Check if puppet service running, start if not
         if [[ ! "$(service puppet status)" =~ "agent is running" ]];
            then service puppet start
         fi
         #puppet agent --fingerprint
       else #No "-oob-" or "erase" in hostname
         #Check if puppet is installed, install if not
         if [[ $(dpkg-query -W -f='${Status}' puppet 2>/dev/null | grep -c "ok installed") = 0 ]];
            then
              apt-get update
              apt-get install puppet -y
         fi
         #Collect MAC addresses of the MGMT interface
         MAC_eth0=`/bin/echo eth0 MAC: $(facter macaddress_eth0)`
         #Collect MAC address of bridge interface (all SVIs will inherit this on VLAN aware bridge)
         MAC_bridge=`/bin/echo bridge MAC: $(facter macaddress_bridge)`
         #Collect device's Serial Number
	 SerialNumber=`/usr/cumulus/bin/decode-syseeprom | awk '/Serial Number/ {print "Serial Number: " $NF}'`
         #Collect device's Service Tag
         ServiceTag=`/usr/cumulus/bin/decode-syseeprom | awk '/Service Tag/ {print "Service Tag: " $NF}'`
         #Collect current IP address
         IP_address=`/bin/echo IP Address: $(facter ipaddress)`
         #Check if curl is installed, install if not
         if [[ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") = 0 ]];
            then 
              apt-get update
              apt-get install curl -y
         fi
         curl -X POST -H "Content-type: application/json" --data '{"text":"Awaiting DHCP reservation switch with:\n'"$SerialNumber"'\n'"$ServiceTag"'\n'"$MAC_eth0"'\n'"$MAC_bridge"'\n'"$IP_address"'"}' https://hooks.slack.com/services/afasfahgadf/dafasdfadgas/dasdgaddff
   fi
 else	# Network is down		 	
   exit 0		
fi

