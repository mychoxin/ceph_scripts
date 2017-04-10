#!/bin/bash

stop_daemon()
{
    	pidlist=$1
    	signal=$2
    	for pid in $pidlist; do
		kill $signal $pid
	done
}

umount_all()
{
	osddatas=`grep "osd data =" $cls_dir/ceph.conf | awk -F "osd data =" '{print $2}'`
	for mp in $osddatas ; do
		umount -l $mp
	done
}

cls_dir=/etc/ceph

if [ ! -f $cls_dir/ceph.conf ]; then
	echo "configuration file $cls_dir/ceph.conf doesn't exist"
	exit 1
fi

read -r -p "$cls_dir will be deleted, all the data will be lost, are you sure? [y/N] " response
response=${response,,}    # tolower
if [[ $response =~ ^(yes|y)$ ]]
then
	echo
else
        exit 1
fi

osdpids=`pidof ceph-osd`
monpids=`pidof ceph-mon`

if [ ! -z "$osdpids" ];then
	echo "kill osd daemons"
	stop_daemon $osdpids -9
	umount_all
fi

if [ ! -z $monpids ];then
	echo "kill mon daemon"
	stop_daemon $monpids -9
fi

rm -rf $cls_dir

exit 0
