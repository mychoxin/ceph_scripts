#!/bin/bash -f
if [ "$#" != "2" ]
then
        echo "Usage: $0 <osd_num> <osd_size_in_MB>"
        exit
fi

cls_dir=/etc/ceph
if [ -e $cls_dir/ceph.conf ]
then
	echo "found data under $cls_dir, please remove it."
	exit 1
fi

osd_count=$1
osd_size=$2
export cls_dir

mkdir -p $cls_dir

script_path=`dirname $0`

host_ip=`ip -4 -o addr | /bin/grep -E '(eth|wlan)' |  awk '{split($4,a,"/");print a[1]}' | head -n 1`

$script_path/create_mon.sh $cls_dir/ceph.conf $cls_dir

for ((osdid=0; osdid<$osd_count; ++osdid))
do
	$script_path/create_osd.sh $osdid $cls_dir  $cls_dir/ceph.conf $osd_size
done

echo "waiting ceph cluster to startup"

sleep 10

