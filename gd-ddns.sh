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
    
mydomain=$(jq -r ".domain" gd-keys.json)
myhostname=$(jq -r ".hostname" gd-keys.json)
key=$(jq -r ".key" gd-keys.json)
secret=$(jq -r ".secret" gd-keys.json)
gdapikey="$key:$secret"

myip=`curl -s "https://api.ipify.org"`

dnsdata=`curl -s -X GET -H "Authorization: sso-key ${gdapikey}" "https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}"`

gdip=$(echo "$dnsData" | jq -r ".[0].data")
if [[ "$gdip" == "" ]]; then
    code=$(echo "$dnsdata" | jq -r ".code")
    error=$(echo "$dnsdata" | jq -r ".message")
    echoit sys err 0x90000007 $code "$error"
    exit 1
fi
if [ "$gdip" != "$myip" -a "$myip" != "" ]; then
    echoit sys info 0x90000002 $myhostname.$mydomain $myip $gdip

    url=https://api.godaddy.com/v1/domains/${mydomain}/records/A/${myhostname}
    curl -s -X PUT "${url}" -H "Authorization: sso-key ${gdapikey}" -H "Content-Type: application/json" -d "[{\"data\": \"${myip}\"}]"
	if [[ "$?" != "0" ]]; then
        echoit sys err 0x90000003 $myhostname.$mydomain $myip $gdip
	else
        echoit sys info 0x90000001 $myhostname.$mydomain $myip $gdip
    fi
else
    echoit sys info 0x90000004 $myhostname.$mydomain $myip 
fi
