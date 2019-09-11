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

def handle(pkt, args):
    if pkt[Ether].dst != mac_addresses[args.src]:
        print "Received packet of {0}".format(pkt[Ether].dst)
        return

    print "Received 1 packet"
    pkt.show()
    if pkt.haslayer(AcquireBlock):
        resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                FlowControl() / Tilelink(source=pkt[Tilelink].source, param=2, m_size=6) / \
                GrantData(sink=args.src,
                    data="1234567890-=qwertyuiop[]asdfghjklzxcvbnm")
                    # w0=0x40414243, w1=0x44454647, w2=0x47495051, w3=0x52535455,
                    # w4=0x56575859, w5=0x60616263, w6=0x64656667, w7=0x68697071,
                    # w8=0x72737475, w9=0x76777879, w10=0x80818283, w11=0x84858687,
                    # w12=0x88899091, w13=0x92939495, w14=0x96979899, w15=0xA0A1A2A3)
        sendp(resp, iface=args.iface)
    elif pkt.haslayer(ProbeBlock):
        resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                FlowControl() / Tilelink(param=Prune['TtoB']) / \
                ProbeAck(addr=pkt[ProbeBlock].addr)
        sendp(resp, iface=args.iface)

    elif pkt.haslayer(Release):
        resp = Ether(dst=pkt[Ether].src, src=pkt[Ether].dst) / \
                FlowControl() / Tilelink(source=pkt[Tilelink].source, param=Prune['TtoN']) / \
                ReleaseAck(addr=pkt[Release].addr)
        sendp(resp, iface=args.iface)


if __name__=='__main__':
    parser = argparse.ArgumentParser(description='Craft TileLink messages.')
    parser.add_argument('-i', '--iface', help='sniffing interface', default='eth0')
    parser.add_argument('-s', '--src', type=int, help='source MAC', default=1)
    args = parser.parse_args()
    if args.iface:
        args.my_mac = get_if_hwaddr(args.iface)
        filter_str = 'ether proto %s and ether dst %s' % (TILELINK_TYPE, args.my_mac)
        sniff(iface=args.iface, filter=filter_str, prn=lambda x: handle(x, args))
    else:
        print("Expected interface name")
