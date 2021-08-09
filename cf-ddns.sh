#!/bin/bash

#from https://www.instructables.com/Quick-and-Dirty-Dynamic-DNS-Using-GoDaddy

function echoit() 
{
    if [[ ! -f /usr/syno/bin/synologset1 ]]; then
        echo $1 $2 $3 $4 $5 $6 $7 $8 $9
    else
        synologset1 $1 $2 $3 $4 $5 $6 $7 $8 $9
    fi
}

proxy=$(jq -r ".proxy" cf-keys.json)
mydomain=$(jq -r ".domain" cf-keys.json)
myhostname=$(jq -r ".hostname" cf-keys.json)
usernameID=$(jq -r ".usernameID" cf-keys.json)
accountID=$(jq -r ".accountID" cf-keys.json)
apiKEY=$(jq -r ".apiKEY" cf-keys.json)
tokenID=$(jq -r ".tokenID" cf-keys.json)

myip=`curl -s "https://api.ipify.org"`

listDNSAPI="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records?type=A&name=${myhostname}.${mydomain}"

dnsData=$(curl -s -X GET "$listDNSAPI" -H "Authorization: Bearer $tokenID" -H "Content-Type:application/json")

resSuccess=$(echo "$dnsData" | jq -r ".success")
if [[ $resSuccess != "true" ]]; then
	echoit sys err 0x90000007 "Unknown error" "$dnsData"
    echo "badauth"
    exit 1
fi

cfID=$(echo "$dnsData" | jq -r ".result[0].id")
cfIP=$(echo "$dnsData" | jq -r ".result[0].content")

echo "IP address on CloudFlare is currently set to $cfIP with record ID=$cfID"

if [ "$cfIP" != "$myip" -a "$myip" != "" ]; then
	echoit sys info 0x90000002 $myhostname.$mydomain $myip $cfIP
	echo "IP is out of date!!"

    if [[ $cfID = "null" ]]; then
        echo "DNS Record for $myhostname.$mydomain does not exist, creating"
        cmd=POST
        api="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records"
        echoit sys err 0x90000005 $myhostname.$mydomain
    else
        echo "Updating IP address for $myhostname.$mydomain to $myip from $cfIP"
        cmd=PUT
        api="https://api.cloudflare.com/client/v4/zones/${usernameID}/dns_records/${cfID}"
        echoit sys err 0x90000006 $myhostname.$mydomain
    fi
    res=$(curl -s -X $cmd "$api" -H "Authorization: Bearer $tokenID" -H "Content-Type:application/json" --data "{\"type\":\"A\",\"name\":\"${myhostname}.${mydomain}\",\"content\":\"$myip\",\"proxied\":$proxy}")
    resSuccess=$(echo "$res" | jq -r ".success")
    if [[ $resSuccess != "true" ]]; then
        echoit sys err 0x90000003 $myhostname.$mydomain $myip $cfIP
        exit 1
    else
        echoit sys info 0x90000001 $myhostname.$mydomain $myip $cfIP
        exit 0
    fi
else
   #echoit sys info 0x90000004 $myhostname.$mydomain $myip 
   exit 0
fi
