Welcome to the OmniXtend future!
================================

OmniXtend is a fully open networking protocol for exchanging
coherence messages directly with processor caches.

OmniXtend is the most efficient way of attaching new
accelerators, storage and memory devices to RISC-V SoCs.

OmniXtend can be used to create multi-socket RISC-V systems.

OmniXtend uses Ethernet L1 for framing, and so can be switched
with off-the-shelf programmable Ethernet switches such as
Barefoot Tofino.

This initial release of OmniXtend is based on a simple serialization
of the TileLink coherence protocol created for the RISC-V ecosystem.
Future evolution may diverge from the on-chip coherence protocol to
tackle issues of scalability and heterogeneity. It is important to
keep in mind that OmniXtend is *not* equivalent to TileLink, despite 
their similarity at the moment.


See the [specification](specification/OmniXtend-0.1.pdf)
document for details of the protocol.

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
