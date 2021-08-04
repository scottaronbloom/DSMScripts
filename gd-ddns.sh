#!/bin/bash

#from https://www.instructables.com/Quick-and-Dirty-Dynamic-DNS-Using-GoDaddy

mydomain="towel42.com"
myhostname="beachbox"
key=""
secret=""
gdapikey="$key:$secret"

myip=`curl -s "https://api.ipify.org"`


#echo "IP address should be $myip for $myhostname.$mydomain"

dnsdata=`curl -s -X GET -H "Authorization: sso-key ${gdapikey}" "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}"`

gdip=`echo $dnsdata | cut -d ',' -f 1 | tr -d '"' | cut -d ":" -f 2`
#echo "IP address on GoDaddy is currently set to $gdip"

if [ "$gdip" != "$myip" -a "$myip" != "" ]; then
    synologset1 sys info 0x90000002 $myhostname.$mydomain $myip $gdip
    #echo "IP is out of date!!"
    #echo "Updating IP address for $myhostname.$mydomain to $myip from $gdip"

    url=https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}
    curl -s -X PUT "${url}" -H "Authorization: sso-key ${gdapikey}" -H "Content-Type: application/json" -d "[{\"data\": \"${myip}\"}]"
	if [[ "$?" != "0" ]]; then
        synologset1 sys err 0x90000003 $myhostname.$mydomain $myip $gdip
	else
        synologset1 sys info 0x90000001 $myhostname.$mydomain $myip $gdip
    fi
else
    synologset1 sys info 0x90000004 $myhostname.$mydomain $myip 
    #echo "IP already correct, no update necessary"
fi
