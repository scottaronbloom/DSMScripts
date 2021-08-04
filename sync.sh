#!/bin/bash

Usage() {
	echo "sync.sh: [--force] [--logdir <log directory>] [--srcdir <src dir>] [--port <port>] [-help]"
	echo "    Sync's the media from the specified source directories to the remote destination"
	echo "    -f|--force : Ignores the current lockfile"
	echo "    -l|--logdir: Sets the log directory (default '$LOGDIR')"
	echo "       --srcdir: Sets the source directory on this machine (default '$SRC_DIR')"
	echo "     --syncdirs: Sets the sync directories machine, each syncdirectory is a subdirectory of --srcdir (default '$SYNC_DIRS')"
	echo "         --dest: Sets the destination machine (default is based on the last VPN connection for user $USER )"
	echo "      --destdir: Sets the destination directory on the remote machine (default '$DEST_DIR')"
	echo "     --syncdirs: Sets the sync directories machine, each syncdirectory is a subdirectory of --srcdir (default '$SYNC_DIRS')"
	echo "    -u|  --user: Sets the remote user name (default '$USER')"
	echo "    -i| --ident: Sets the local identity file (default '$IDENT_FILE')"
	echo "    -p|--port  : Sets the ssh port on the destination machine (default '$PORT')"
	echo ""
	echo "    -h|--help  : Displays this message"
}
SYNCDIR=/usr/local/sbin/sync
LOGDIR=$SYNCDIR/synclogs
PORT=22
SRC_DIR="/volume2"
SYNC_DIRS="music photo video"
DEST=DEFAULT
DEST_DIR=/volume1
USER=scott
IDENT_FILE=/var/services/homes/${USER}/.ssh/id_rsa
FORCE="NO"

while [[ $# -gt 0 ]]; do
	switch="$1"

	case $switch in
		-f*|--force)
			FORCE="YES"
			shift
		;;
		-l*|--logdir)
			LOGDIR=$2
			shift
			shift
		;;
		--destdir)
			DEST_DIR=$2
			shift
			shift
		;;
		--dest)
			DEST=$2
			shift
			shift
		;;
		--srcdir)
			SRC_DIR=$2
			shift
			shift
		;;
		--syncdirs)
			SYNC_DIRS=$2
			shift
			shift
		;;
		-u*|--user)
			USER=$2
			shift
			shift
		;;
		-i*|--ident)
			IDENT_FILE=$2
			shift
			shift
		;;
		-p*|--port)
			PORT=$2
			shift
			shift
		;;
		-h*|--help)
			Usage
			exit 0
		;;
		*)
			echo "Unknown Option: [$switch]" 1>&2
			synologset1 sys err 0x90010001 $switch
			Usage
			exit -1
		;;
	esac
done

LOCKFILE=$LOGDIR/lockfile
LOGFILE=$LOGDIR/synclog.`date +%m-%d-%Y.%H%M%S.%N`.txt

if [ ! -d $SYNCDIR ]; then
	echo "Could not find sync directory [$SYNCDIR]." 1>&2
	synologset1 sys err 0x90010002 $SYNCDIR
	exit -1
fi

cd $SYNCDIR

if [ -f $LOCKFILE ]; then
	if [[ "$FORCE" == "YES" ]]; then
		echo "--force is enabled, lockfile [$LOCKFILE] will be removed."
		synologset1 sys warn 0x90010003 $LOCKFILE
		sleep 1s
		rm $LOCKFILE
		if [[ -f $LOCKFILE ]]; then
			echo "Could not remove locfile.  Please check permssions on [$LOCKFILE]." 1>&2
			synologset1 sys err 0x90010004 $LOCKFILE
			exit -1
		fi
	fi
fi

if [ -f $LOCKFILE ]; then
	echo "Sync is currently running. Please remove [$LOCKFILE] or run with --force if this is a mistake." 1>&2
	synologset1 sys err 0x90010005 $LOCKFILE
	exit -1
fi

if [[ ! -f $IDENT_FILE ]]; then
	echo "Could not find identity file [$IDENT_FILE] please check path and permissions." 1>&2
	synologset1 sys err 0x90010006 $IDENT_FILE
	exit -1
fi


if [[ ! -d $LOGDIR ]]; then
	mkdir -p $LOGDIR
fi
if [[ ! -d $LOGDIR ]]; then
	echo "Log directory '$LOGDIR' does not exist and could not be created" 1>&2
	synologset1 sys err 0x90010007 $LOGDIR
	exit -1
fi

echo $$ > $LOCKFILE
LATESTFILE=$SYNCDIR/latestSyncLog.txt
rm -rf $LATESTFILE

touch $LOGFILE
echo "Sync started @ [`date "+%H:%M:%S on %m-%d-%Y"`]" | tee -a $LOGFILE
echo "========================================================================" | tee -a $LOGFILE
synologset1 sys info 0x90010008 `date "+%H:%M:%S on %m-%d-%Y"`
sleep 1s
ln -s $LOGFILE $LATESTFILE

if [ ! -d $LOGDIR/oldlogs ]; then 
	mkdir -p $LOGDIR/oldlogs
fi

OLDLOGS=`find $LOGDIR -mmin +1440 -name \*.txt`
if [ "$OLDLOGS" != "" ]; then
	echo "Moving old log files." | tee -a $LOGFILE
	synologset1 sys info 0x90010009
	sleep 1s
	mv $OLDLOGS $LOGDIR/oldlogs
	gzip $LOGDIR/oldlogs/*.txt
fi

OLDOLDLOGS=`find $LOGDIR -mmin +10080 -name \*.txt.gz`
if [ "$OLDOLDLOGS" != "" ]; then
	echo "Deleting really old log files." | tee -a $LOGFILE
	synologset1 sys info 0x90010010
	sleep 1s
	rm $OLDOLDLOGS
fi

if [[ "$DEST" == "DEFAULT" ]]; then
	echo "Determining IP Address for VPN connected user [$USER]." | tee -a $LOGFILE
	synologset1 sys info 0x90010016 $USER
	sleep 1s
	VPN_INFO=`/usr/local/sbin/vpnip.sh $USER -s`
	if [[ "$VPN_INFO" == "Disconnected" ]]; then
		echo "User [$USER] is currently disconnected." | tee -a $LOGFILE
		synologset1 sys error 0x90010017 $USER
		sleep 1s
		exit -1
	else
		VPN_INFO_ARR=(${VPN_INFO//,/ })
		DEST=${VPN_INFO_ARR[0]}
		SRC_IP=${VPN_INFO_ARR[1]}
		
		echo "User [$USER] is connected via IP Address [$DEST] from [$SRC_IP]." | tee -a $LOGFILE
		synologset1 sys info 0x90010018 $USER $DEST $SRC_IP
		sleep 1s
	fi
fi

retCode=0
syncErrorDir=
for currDir in $SYNC_DIRS; do
	echo "==========================================" | tee -a $LOGFILE
	synologset1 sys info 0x90010011 $SRC_DIR/$currDir
	sleep 1s
	echo "Syncing [$SRC_DIR/$currDir]" | tee -a $LOGFILE
	echo "==========================================" | tee -a $LOGFILE

	if [ ! -d "$SRC_DIR/$currDir" ]; then
		synologset1 sys err 0x90010012 $SRC_DIR/$currDir
		sleep 1s
		echo "Source Directory [$SRC_DIR/$currDir] does not exist." | tee -a $LOGFILE
		continue
	fi
	pushd $SRC_DIR/$currDir > /dev/null
	# pwd
	localRetCode=0
	( time rsync -e "ssh -p $PORT -i '$IDENT_FILE'" -azv --omit-dir-times --partial --progress --delete --delete-excluded --exclude .dropbox.cache --exclude '.hg' --exclude '.svn' --exclude 'build' --exclude 'build.64' . rsync://$USER@$DEST/sync/$DEST_DIR/$currDir ) |& tee -a $LOGFILE
	localRetCode=${PIPESTATUS[0]}
	popd > /dev/null
	if [[ $localRetCode -eq 0 ]]; then
		synologset1 sys info 0x90010013 $SRC_DIR/$currDir
		sleep 1s
		echo "Sucessfully finished syncing [$currDir]." | tee -a $LOGFILE
	else
		retCode=1
		synologset1 sys err 0x90010014 $SRC_DIR/$currDir
		sleep 1s
		echo "Error syncing $currDir" | tee -a $LOGFILE
		continue
	fi
done
echo "========================================================================" | tee -a $LOGFILE
sleep 1s
synologset1 sys info 0x90010015 `date "+%H:%M:%S on %m-%d-%Y"`
echo "Sync Finished @ [`date "+%H:%M:%S on %m-%d-%Y"`]" | tee -a $LOGFILE
rm -rf $LOCKFILE
exit $retCode
