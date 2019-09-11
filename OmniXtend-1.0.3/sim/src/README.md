# Implementing Cache Coherence Fabric

## Introduction

The objective of this exercise is to write a P4 program that implements basic
coherence protocol. To keep things simple, we will just implement cache
ownership.

With coherence protocol, the switch must perform the following actions:
(i) find the owner of a cache block. If the cache block doesn't have an owner,
    forward the request to the memory controller
(ii) when the memory controller (or the current owner) grants exclusive access
    to the cache block, the switch stores the ID of the new owner
(iii) the switch modifies the destination MAC address of the packet to match
    the MAC address of the cache owner

The control plane will populate match-action tables with static rules.
We have already defined the control plane rules.

We will use the linear topology for this exercise. It is a single switch that
connects four hosts as follow:

                    h1         h2
                    |          |
              ---------------------------- s1
                          |        |
                         h3        h4

Our P4 program will be written for the V1Model architecture implemented on
P4.org's bmv2 software switch. The architecture file for the V1Model can be
found at: `/home/vagrant/p4c/p4include/v1model.p4`. This file describes the
interfaces of the P4 programmable elements in the architecture, the supported
externs, as well as the architecture's standard metadata fields. We encourage
you to take a look at it.


## Run the code step by step

**Prerequisite**:
Allow user `vagrant` to capture packets without sudo.
[Follow the guide here](https://askubuntu.com/questions/74059/how-do-i-run-wireshark-with-root-privileges)

The directory with this README also contains a P4 program,
`omnixtend.p4`, which already implements the tables and registers to handle and
forward cache coherence requests.

Let's compile and bring up a switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make run
   ```
   This will:
   * compile `omnixtend.p4`, and
   * start the sig-topo in Mininet and configure all switches with
   the appropriate P4 program + table entries, and
   * configure all hosts with the commands listed in
   [sig-topo/topology.json](./sig-topo/topology.json)

2. You should now see a Mininet command prompt. Try to ping between
   hosts in the topology:
   ```bash
   mininet> h1 ping h2
   mininet> pingall
   ```

3. In a new terminal, run:
 `wireshark -X lua_script:~/omnixtend/tutorial/src/omnixtend.lua`

4. In wireshark, start capturing on interface `s1-eth1`

5. In the first terminal, run:

 `xterm h1 h2 h3 h4`

6. In the xterm of `h1`, run the memory controller:

    `python memory_controller.py`

7. In the xterm of `h2`, run a cache controller which will send an Acquire
  request for a fixed memory address (e.g., 0x0000000200008000).

    `python cache_controller.py -s 2`

  If you go back to the wireshark window, you could see the switch receives
  a sequence of messages `AcquireBlock > GrantData > GrantAck`

8. In the xterm of `h3` run another cache controller which does the same
  things as `h2` does

  `python cache_controller.py -s 3`

  You could see in the xterm of `h3`, it receives a `Grant` message from `h2`
  and sends an `GrantAck` response.

9. Type `exit` to leave each xterm and the Mininet command line.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```


### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules within each
table are inserted by the control plane. When a rule matches a packet, its
action is invoked with parameters supplied by the control plane as part of the
rule.

In this exercise, we have already implemented the control plane logic for you.
As part of bringing up the Mininet instance, the `make run` command will install
packet-processing rules in the tables of each switch. These are defined in the
`sX-runtime.json` files, where `X` corresponds to the switch number. In this
exercise, we only have a switch `s1`.

**Important:**
We use P4Runtime to install the control plane rules. The content of files
`sX-runtime.json` refer to specific names of tables, keys, and actions, as
defined in the P4Info file produced by the compiler (look for the file
`build/omnixtend.p4.p4info.txt` after executing `make run`). Any changes in the
P4 program that add or rename tables, keys, or actions will need to be reflected
in these `sX-runtime.json` files.


### Food for thought

The "test suite" for demonstration purpose is not very robust and complete. What
else should you test to be confident that you implementation is correct?

Other questions to consider:
 - How would you enhance the program to respond to other cache coherence requests?
 - How would you enhance the program to support concurrent requests from the same host?
 - How would you enhance your program to support a complex network topology?

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `omnixtend.p4` might fail to compile. In this case, `make run` will
report the error emitted from the compiler and halt.

2. `omnixtend.p4` might compile but fail to support the control plane rules in
the `s1-runtime.json` file that `make run` tries to install using P4Runtime. In
this case, `make run` will report errors if control plane rules cannot be
installed. Use these error messages to fix your `omnixtend.p4` implementation.

3. `omnixtend.p4` might compile, and the control plane rules might be installed,
but the switch might not process packets in the desired way. The `logs/sX.log`
files contain detailed logs that describing how each switch processes each
packet. The output is detailed and can help pinpoint logic errors in your
implementation.

#### Cleaning up Mininet

In the latter two cases above, `make run` may leave a Mininet instance
running in the background. Use the following command to clean up
these instances:

```bash
make stop
```
