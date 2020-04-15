OmniXtend version 1.0.3 released!
================================

OmniXtend is a fully open networking protocol for exchanging
coherence messages directly with processor caches, memory
controllers and various accelerators.

OmniXtend is the most efficient way of attaching new
accelerators, storage and memory devices to RISC-V SoCs.

OmniXtend can be used to create multi-socket RISC-V systems.

OmniXtend uses Ethernet L2 for framing, and so can be switched
with off-the-shelf Ethernet switches. Programmable-dataplane Ethernet
switches, such as Barefoot Tofino, enable greatly improved performance
and protocol/architectural innovation.

See the current [specification](OmniXtend-1.0.3/spec/OmniXtend-1.0.3.pdf)
document for details of the protocol. OmniXtend 1.0.3 is based on
[TileLink version 1.8.0](OmniXtend-1.0.3/spec/TileLink-1.8.0.pdf).
[This document](OmniXtend-1.0.3/spec/StateTransitionTables-1.8.0.pdf)
can help with the creation of state machines for caches, accelerators
and memory controllers.

This [short video](https://youtu.be/hmVNTUrJoDM) shows how to set
up the demo system.

License
=======

OmniXtend is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

The protocol specification is provided under Apache 2.0 license.

The reference hardware implementations include a linux
distribution provided under the GPL v2 license.

The Initialization Protocol specification is provided under the
Creative Commons Attribution 4.0 International License
