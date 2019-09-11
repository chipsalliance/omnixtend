#!/bin/bash -e

if [ -f /etc/debian_version ]; then
    OS="Debian"
    VER=$(cat /etc/debian_version)
    sudo apt-get update && sudo apt-get install -y build-essential git libnuma-dev
elif [ -f /etc/redhat-release ]; then
    OS="Red Hat"
    VER=$(cat /etc/redhat-release)
    sudo yum install -y git libnuma-dev
fi

# Install DPDK Dependency
cd $HOME
git clone git://dpdk.org/dpdk
cd dpdk
export RTE_SDK=$HOME/dpdk
export RTE_TARGET=x86_64-native-linuxapp-gcc
git checkout v19.08
make config T=$RTE_TARGET O=$RTE_TARGET
sed -i 's/HPET=n/HPET=y/g' $RTE_SDK/$RTE_TARGET/.config
sed -i 's/VECTOR=y/VECTOR=n/g' $RTE_SDK/$RTE_TARGET/.config
make O=$RTE_TARGET
cat <<EOF >> $HOME/.bashrc
export RTE_SDK=$HOME/dpdk
export RTE_TARGET=x86_64-native-linuxapp-gcc
EOF
