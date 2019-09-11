# Install DPDK Dependency

```
./install_dpdk.sh
```


# Build OmniXtend

```
make
```

# Init System

Assuming the NIC with PCIe address 01:00.0 is connected to the FPGA. The script
will reserve HUGEPAGE memory and bind the NIC to DPDK driver (igb_uio).

```
sudo -E ./init_dpdk.sh
```

# Run OmniXtend

```
sudo ./build/omnixtend -l 0 -n 4 --log-level 7
```
