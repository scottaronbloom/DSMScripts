#!/bin/bash

#from https://www.instructables.com/Quick-and-Dirty-Dynamic-DNS-Using-GoDaddy

proxy=true
mydomain="towel42.com"
myhostname="beachbox"
usernameID=""
accountID=""
apiKEY=""
tokenID=""

myip=`curl -s "https://api.ipify.org"`

listDNSAPI="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records?type=A&name=${myhostname}.${mydomain}"

dnsData=$(curl -s -X GET "$listDNSAPI" -H "Authorization: Bearer $tokenID" -H "Content-Type:application/json")

resSuccess=$(echo "$dnsData" | jq -r ".success")
if [[ $resSuccess != "true" ]]; then
    echo "badauth"
    exit 1
fi

cfID=$(echo "$dnsData" | jq -r ".result[0].id")
cfIP=$(echo "$dnsData" | jq -r ".result[0].content")

echo "IP address on CloudFlare is currently set to $cfIP with record ID=$cfID"

if [ "$cfIP" != "$myip" -a "$myip" != "" ]; then
#	synologset1 sys info 0x90000002 $myhostname.$mydomain $myip $cfIP
	echo "IP is out of date!!"

    if [[ $cfID = "null" ]]; then
        echo "DNS Record for $myhostname.$mydomain does not exist, creating"
        cmd=POST
        api="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records"
    else
        echo "Updating IP address for $myhostname.$mydomain to $myip from $cfIP"
        cmd=PUT
        api="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records/${cfID}"
    fi
    res=$(curl -s -X $cmd "$api" -H "Authorization: Bearer $tokenID" -H "Content-Type:application/json" --data "{\"type\":\"A\",\"name\":\"${myhostname}.${mydomain}\",\"content\":\"$myip\",\"proxied\":$proxy}")
    resSuccess=$(echo "$res" | jq -r ".success")
    if [[ $resSuccess != "true" ]]; then
#       synologset1 sys err 0x90000003 $myhostname.$mydomain $myip $cfIP
        echo "badauth"
        exit 1
    else
#       synologset1 sys info 0x90000001 $myhostname.$mydomain $myip $cfIP
        echo "good"
        exit 0
    fi

#	if [[ "$?" != "0" ]]; then
#	else
#	fi
else
#	synologset1 sys info 0x90000004 $myhostname.$mydomain $myip 
   echo "IP already correct, no update necessary"
   exit 0
fi
