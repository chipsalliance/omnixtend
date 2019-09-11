#!/bin/bash


if [ "$EUID" -ne 0 ] ;  then
	echo "Please run as root"
	echo "sudo -E ./setup.sh"
	exit -1
fi

if [ -z ${RTE_SDK} ]; then
	echo "Please set \$RTE_SDK variable"
	echo "sudo -E ./setup.sh"
	exit -1
fi

modprobe uio
sudo insmod $RTE_SDK/$RTE_TARGET/kmod/igb_uio.ko
$RTE_SDK/usertools/dpdk-devbind.py --status

sudo mkdir -p /mnt/huge
sudo mount -t hugetlbfs nodev /mnt/huge/
echo 4096 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages

$RTE_SDK/usertools/dpdk-devbind.py --bind=igb_uio 01:00.0
$RTE_SDK/usertools/dpdk-devbind.py --bind=igb_uio 01:00.1
$RTE_SDK/usertools/dpdk-devbind.py --status
