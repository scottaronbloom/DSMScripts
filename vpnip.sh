#!/bin/bash

Usage() {
	echo "vpnip: [--time] [--src_ip] <user> [-help]"
	echo "    Returns the IP address in which the <user> (default is $USER) is currently connected via VPN"
	echo "     -t|--time  : Returns the time of the last connection"
	echo "     -s|--src_ip: Returns the Source IP address of the connection"
	echo ""
	echo "     -h|--help  : Displays this message"
}
TIME="NO"
SRC_IP="NO"
USER=`whoami`
USER_SET="NO"

while [[ $# -gt 0 ]]; do
	switch="$1"
	#echo "Switch=$switch"

	case $switch in
		-t*|--time)
			TIME="YES"
			shift
		;;
		-s*|--src_ip)
			SRC_IP="YES"
			shift
		;;
		-h*|--help)
			Usage
			exit 0
		;;
		*)
			if [[ "$USER_SET" == "YES" ]]; then
				echo "User already set to [$USER]."
				synologset1 sys err 0x90020001 $USER
				exit -1
			fi
			USER="$1"
			USER_SET="YES"
			shift
		;;
	esac
done

synologset1 sys info 0x90020002 $USER $USER_SET $TIME $SRC_IP 
sleep 1s
#echo "Finding VPN Connection infor for user [$USER] Explicit User? [$USER_SET] Report Time? [$TIME] Report Source IP? [$SRC_IP]"

   LAST_CONNECT=`sqlite3 /usr/syno/etc/packages/VPNCenter/synovpnlog.db "select id from synovpn_log_tb where user='$USER' AND event like 'Connected%' order by id desc limit 1;"`
LAST_DISCONNECT=`sqlite3 /usr/syno/etc/packages/VPNCenter/synovpnlog.db "select id from synovpn_log_tb where user='$USER' AND event like 'Disconnected%' order by id desc limit 1;"`
#| sed s/.*as// | sed s/.$// |  tr -d ' []'`
#echo "CONNECT=$LAST_CONNECT"
#echo "DISCONNECT=$LAST_DISCONNECT"

if [[ $LAST_DISCONNECT > $LAST_CONNECT ]]; then
	synologset1 sys info 0x90020003 $USER 
	echo "Disconnected"
else
	VPN_IP=`sqlite3 /usr/syno/etc/packages/VPNCenter/synovpnlog.db "select event from synovpn_log_tb where ID='$LAST_CONNECT';" | sed s/.*as// | sed s/.$// |  tr -d ' []'`
	synologset1 sys info 0x90020004 $USER $VPN_IP
	if [[ "$SRC_IP" == "YES" ]]; then
		VPN_SRC=`sqlite3 /usr/syno/etc/packages/VPNCenter/synovpnlog.db "select event from synovpn_log_tb where ID='$LAST_CONNECT';" | sed s/.*from// | sed s/as.*// | tr -d ' []'`
		synologset1 sys info 0x90020005 $USER $VPN_SRC
		VPN_SRC=,${VPN_SRC}
	fi
	if [[ "$TIME" == "YES" ]]; then
		VPN_TIME=`sqlite3 /usr/syno/etc/packages/VPNCenter/synovpnlog.db "select time from synovpn_log_tb where ID='$LAST_CONNECT';"`
		synologset1 sys info 0x90020006 $USER $VPN_TIME
		VPN_TIME=,${VPN_TIME}
	fi
	echo ${VPN_IP}${VPN_SRC}${VPN_TIME}
fi
exit 0
