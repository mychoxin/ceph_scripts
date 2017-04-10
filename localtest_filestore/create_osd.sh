#!/bin/bash

set -e 

if [ "$#" != "4" ]
then
        echo "Usage: $0 <id> <data_dir> <config_file> <size_in_MB>"
        exit
fi

id=$1
osd_data=$2/osd.$id  #the dir where osd device is mounted to
osd_host=`hostname -s`   #host name, where osd running
conf_file=$3
osd_size=$4

if [ ! -f $conf_file ];
then
   echo "$conf_file not exists."
   exit
fi

journal_file=$2/osd.$id.journal
if [ -f $journal_file ];
then
	read -r -p "$journal_file already exists, delete it? [y/N] " response
	response=${response,,}    # tolower
	if [[ $response =~ ^(yes|y)$ ]]
	then
		rm -f $journal_file
	else
		exit
	fi
fi

if [ ! -d $osd_data ];
then
	mkdir -p $osd_data   
fi
echo "OSD data dir: $osd_data"

osd_img=$2/osd.$id.img
if [ -f $osd_img ];
then
	read -r -p "Disk image file $osd_img already exists, delete it? [y/N] " response
	response=${response,,}    # tolower
	if [[ $response =~ ^(yes|y)$ ]]
	then
		rm -f $osd_img
	else
		exit
	fi
fi

dd if=/dev/zero of=$osd_img bs=1M count=0 seek=$osd_size #2048个1M block，共2G
mkfs.xfs -f $osd_img

sed -i "/\[osd\.$id\]/, +5 d" $conf_file #delete old config for this osd

echo "[osd.$id]" >> $conf_file
echo "	host = $osd_host" >> $conf_file
echo "	devs = $osd_img" >> $conf_file
echo "	osd journal = $2/\$name.journal" >> $conf_file
echo "	osd data = $osd_data" >> $conf_file
echo "mount command is mount $osd_img $osd_data"
mount $osd_img $osd_data

echo "create osd"

ceph osd create  -c $conf_file

ceph-osd -i $id --mkfs --mkkey -c $conf_file

ceph auth add osd.$id osd 'allow *' mon 'allow profile osd' -i $osd_data/keyring -c $conf_file 

# only executed when add first OSD
if  ceph osd tree -c $conf_file | grep "host $osd_host"  ; 
then 
	echo Host $osd_host existing in bucket.
else 
	echo Add new host "$osd_host" into bucket
	ceph osd crush add-bucket $osd_host host    -c $conf_file 
	ceph osd crush move $osd_host root=default -c $conf_file
fi

ceph osd crush add osd.$id 1.0 host=$osd_host -c $conf_file

#run the osd service
echo Now start OSD service ...
echo "id:$id conf_file:$conf_file"
set -v
ceph-osd -i $id -c $conf_file
