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
from scapy.all import *
import sys, os
import argparse
conf.sniff_promisc=False

mac_addresses = {
    1 : "08:00:00:00:01:11",
    2 : "08:00:00:00:02:22",
    3 : "08:00:00:00:03:33",
    4 : "08:00:00:00:04:44"
}

TILELINK_TYPE = 0x0870

NtoChan = {
    1 : 'A',
    2 : 'B',
    3 : 'C',
    4 : 'D',
    5 : 'E',
    6 : 'F'
}

Channels = {
    'A' : 1,
    'B' : 2,
    'C' : 3,
    'D' : 4,
    'E' : 5,
    'F' : 6
}

Cap = {
      'toT' : 0,
      'toB' : 1,
      'toN' : 2
}

Grow = {
     'NtoB' : 0,
     'NtoT' : 1,
     'BtoT' : 2
}

Prune = {
    'TtoB' : 0,
    'TtoN' : 1,
    'BtoN' : 2
}

Report = {
    'TtoT' : 3,
    'BtoB' : 4,
    'NtoN' : 5
}



class FlowControl(Packet):
    name = "Retransmit & Flow control"
    fields_desc = [
        BitField("vc", 3, 3),
        BitField("r1", 0, 7),
        BitField("sequence number", 0x2E50D, 22),
        BitField("sequence number_ack", 0x56D4B, 22),
        BitField("ack", 1, 1),
        BitField("r2", 0, 1),
        BitField("chan", 2, 3),
        BitField("credit", 8, 5)
    ]


class Tilelink(Packet):
    name = "Tilelink header"
    fields_desc = [
        BitField("r1", 0, 1),
        BitField("channel", 0, 3),
        BitField("opcode", 0, 3),
        BitField("r2", 0, 1),
        BitField("param", 0, 4),
        BitField("m_size", 5, 4),
        BitField("domain", 0, 8),
        BitField("r3", 0, 6),
        BitField("err", 0, 2),
        BitField("r4", 0, 6),
        BitField("source", 0, 26)
    ]

class Get(Packet):
    name = "Get"
    fields_desc = [
        XLongField("addr", 0)
    ]

class PutFullData(Packet):
    name = "Put Full Data"
    fields_desc = [
        XLongField("addr", 0),
        StrFixedLenField("data", '', 64)
    ]


class PutPartialData(Packet):
    name = "Put Full Data"
    fields_desc = [
        XLongField("addr", 0),
        XLongField("mask", 0),
        StrFixedLenField("data", '', 64)
    ]

class Intent(Packet):
    name = "Intent"
    fields_desc = [
        XLongField("addr", 0)
    ]

class AcquireBlock(Packet):
    name = "AcquireBlock"
    fields_desc = [
        XLongField("addr", 0)

    ]

class AcquirePerm(Packet):
    name = "AcquirePerm"
    fields_desc = [
        XLongField("addr", 0)
    ]

class ProbeBlock(Packet):
    name = "ProbeBlock"
    fields_desc = [
        XLongField("addr", 0)
    ]

class ProbePerm(Packet):
    name = "ProbePerm"
    fields_desc = [
        XLongField("addr", 0)
    ]

class HintAck(Packet):
    name = "Hint Ack"
    fields_desc = [
        XLongField("addr", 0)
    ]

class ProbeAck(Packet):
    name = "Probe Ack"
    fields_desc = [
        XLongField("addr", 0)
    ]


class ProbeAckData(Packet):
    name = "Probe Ack Data"
    fields_desc = [
        BitField("sink", 0, 26),
        BitField("r5", 0, 38),
        StrFixedLenField("data", '', 64)
    ]

class Release(Packet):
    name = "Release"
    fields_desc = [
        XLongField("addr", 0)
    ]

class ReleaseData(Packet):
    name = "Release Data"
    fields_desc = [
        XLongField("addr", 0),
        StrFixedLenField("data", '', 64)
    ]


class AccessAck(Packet):
    name = "AccessAck message"

class ReleaseAck(Packet):
    name = "ReleaseAck message"
    fields_desc = [
        XLongField("addr", 0)
    ]

class HintAck(Packet):
    name = "HintAck message"

class AccessAckData(Packet):
    name = "AccessAckData Message"
    fields_desc = [
        StrFixedLenField("data", '', 64)
    ]

class Grant(Packet):
    name = "Grant Message"
    fields_desc = [
        BitField("sink", 0, 26),
        BitField("r5", 0, 38)
    ]

class GrantData(Packet):
    name = "GrantData Message"
    fields_desc = [
        BitField("sink", 0, 26),
        BitField("r5", 0, 38),
        StrFixedLenField("data", '', 64)
    ]

class GrantAck(Packet):
    name = "GrantAck"
    fields_desc = [
        BitField("sink", 0, 26),
        BitField("r6", 0, 6)
    ]


bind_layers(Ether, FlowControl, type=TILELINK_TYPE)
bind_layers(FlowControl, Tilelink)
#TL-C messages
bind_layers(Tilelink, AcquireBlock, channel=Channels['A'], opcode=6)
bind_layers(Tilelink, AcquirePerm, channel=Channels['A'], opcode=7)
bind_layers(Tilelink, Grant, channel=Channels['D'], opcode=4)
bind_layers(Tilelink, GrantData, channel=Channels['D'], opcode=5)
bind_layers(Tilelink, GrantAck, channel=Channels['E'], opcode=0)
bind_layers(Tilelink, ProbeBlock, channel=Channels['B'], opcode=6)
bind_layers(Tilelink, ProbePerm, channel=Channels['B'], opcode=7)
bind_layers(Tilelink, ProbeAck, channel=Channels['C'], opcode=4)
bind_layers(Tilelink, ProbeAckData, channel=Channels['C'], opcode=5)
bind_layers(Tilelink, Release, channel=Channels['C'], opcode=6)
bind_layers(Tilelink, ReleaseData, channel=Channels['C'], opcode=7)
bind_layers(Tilelink, ReleaseAck, channel=Channels['D'], opcode=6)


if __name__=='__main__':
    parser = argparse.ArgumentParser(description='Craft Tilelink messages.')
    parser.add_argument('-r', '--pcap', help='read from pcap')
    args = parser.parse_args()
    if args.pcap:
        pkts = rdpcap(args.pcap)
        for p in pkts:
            p.show()
