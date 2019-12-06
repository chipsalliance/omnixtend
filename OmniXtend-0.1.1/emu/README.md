
This emulator aims to provide a sample implementation in C of the TileLink over
Ethernet (TLoE) memory target. The software memory target and the
FPGA-based memory target can be used interchangeably. The emulator uses the [Data Plane Development Kit (DPDK)](https://www.dpdk.org) which is a set of data plane libraries and network interface controller drivers for fast packet processing.

## Prerequisites

To run the emulator, a network interface card which supports DPDK is required The list of supported hardware can be found [here](http://core.dpdk.org/supported/). We used a breakout cable to connect a QSFP port of the VCU118 FPGA to a port of the NIC.

## Instructions to compile and to run the emulator

### Install DPDK Dependency
Users can follow instructions to build DPDK at:
http://doc.dpdk.org/guides/linux_gsg/index.html or run the script
`./install_dpdk.sh`


###	Build TLoE memory emulator

Make sure **RTE_SDK** and **RTE_TARGET** environment variables have been set.
Then run `make` to compile the code.

### Init DPDK

Every time the system reboot, users will need to load the *igb_uio* kernel module, reserve *HUGEPAGES*, and bind the NIC to *PMD driver*.

The `init_dpdk.sh` script does just that (Assumed the NIC connected to VCU118 has the PCIe address 01:00.0 and 01:00.1). If the interfaces are active, they need to be deactived before binding. Using this command to deactive the interface:

```
sudo ip link set dev <interface-name> down
```

```
sudo -E ./init_dpdk.sh
```

### Run the emulator

```
sudo ./build/omnix-emulator -l 0 -n 4 --log-level 7
```
