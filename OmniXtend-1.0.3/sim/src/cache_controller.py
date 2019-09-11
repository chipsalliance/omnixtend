#!/usr/bin/env python2
#
# Copyright 2019-present Western Digital Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Tu Dang (tu.dang@wdc.com)
#
import sys, os
import argparse
from scapy.all import *
from tilelink import *

conf.sniff_promisc=False



cache = {}
src_addr = {}

def read_address(args, mem_addr):
    if mem_addr not in cache:
        print "Issue Read"
        acquire = Ether(dst=mac_addresses[args.dst], src=mac_addresses[args.src]) / \
        FlowControl() / Tilelink(param=Grow['NtoB'], source=args.src) / AcquireBlock(addr=mem_addr)
        src_addr[args.src] = mem_addr
        sendp(acquire, iface=args.iface)
        sniff(iface=args.iface, prn=lambda x: handle_resp(x, args))
    else:
        print "Data at Mem[{0}]={1}".format(mem_addr, cache[mem_addr])

def handle_resp(pkt, args):
    if pkt[Ether].dst == mac_addresses[args.src]:
        pkt.show()
        if pkt.haslayer(AcquireBlock):
            if pkt[AcquireBlock].addr not in cache:
                resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                    FlowControl() / Tilelink(source=pkt[Tilelink].source, param=2, m_size=6) / \
                    Grant(sink=args.src)
            else:
                resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                    FlowControl() / Tilelink(source=pkt[Tilelink].source, param=2, m_size=6) / \
                    GrantData(sink=args.src,
                        data=cache[pkt[AcquireBlock].addr])
                del cache[pkt[AcquireBlock].addr]
            sendp(resp, iface=args.iface)
        elif pkt.haslayer(Grant):
            resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                    FlowControl() / Tilelink() / GrantAck(sink=pkt[Grant].sink)
            sendp(resp, iface=args.iface)
        elif pkt.haslayer(GrantData):
            resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                    FlowControl() / Tilelink() / GrantAck(sink=pkt[GrantData].sink)
            if pkt[Tilelink].source in src_addr:
                cache[src_addr[pkt[Tilelink].source]] = pkt[GrantData].data
            print cache
            sendp(resp, iface=args.iface)


def send_tilelink_packet(args):
    acquire = Ether(dst=mac_addresses[args.dst], src=mac_addresses[args.src]) / \
            FlowControl() / Tilelink(param=Grow['NtoB'], source=args.src) / AcquireBlock(addr=0x0000000200008000)

    # release = Ether(dst=mac_addresses[args.dst], src=mac_addresses[args.src]) / \
    #         FlowControl() / Tilelink(param=Prune['TtoN'], source=1) / Release(addr=0x00000002008FF000)
    #
    # probe = Ether(dst=mac_addresses[args.dst], src=mac_addresses[args.src]) / \
    #         FlowControl() / Tilelink(param=Cap['toT'], source=1) / ProbeBlock(addr=0x0000000200ABC000)
    #
    # pkts = [acquire, release, probe]
    pkts = [acquire]
    sendp(pkts, iface=args.iface)
    sniff(iface=args.iface, prn=lambda x: handle_resp(x, args))

if __name__=='__main__':
    parser = argparse.ArgumentParser(description='Craft TileLink messages.')
    parser.add_argument('-i', '--iface', help='sniffing interface', default='eth0')
    parser.add_argument('-c', '--channel', help='Channel', default='B')
    parser.add_argument('-o', '--opcode', type=int, help='Channel', default=6)
    parser.add_argument('-s', '--src', type=int, help='source MAC', default=2)
    parser.add_argument('-d', '--dst', type=int, help='destination MAC', default=1)

    args = parser.parse_args()
    print(args)

    read_address(args, 0x0000000200008000)
    # read_address(args, 0x0000000200008000)
    # send_tilelink_packet(args)
