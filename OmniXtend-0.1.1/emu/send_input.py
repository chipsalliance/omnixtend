from scapy.all import *
import sys, os
import argparse

TILELINK_TYPE = 0x0870
CHANNEL_A = 0
CHANNEL_B = 1
CHANNEL_C = 2
CHANNEL_D = 3
CHANNEL_E = 4
CHANNEL_F = 5

class LLC(Packet):
    name = "Logical link Control"
    fields_desc = [
    ]

class Tilelink(Packet):
    name = "Tilelink"
    fields_desc = [
        ShortField("unused", 0),
        BitField("source", 0, 16),
        BitField("domain", 0, 3),
        BitField("m_size", 0, 4),
        BitField("parm", 0, 3),
        BitField("opcode", 0, 3),
        BitField("channel", 0, 3)
    ]

class Credit(Packet):
    name = "Credit"
    fields_desc = [
        ShortField("unused", 0),
        BitField("e", 0, 5),
        BitField("d", 0, 5),
        BitField("c", 0, 5),
        BitField("b", 0, 5),
        BitField("a", 0, 5),
        BitField("zeros", 0, 4),
        BitField("channel", 0, 3)
    ]

class Address(Packet):
    name = "Address"
    fields_desc = [
        IntField("hi_addr", 0),
        IntField("lo_addr", 0)
    ]

class Grant(Packet):
    name = "Address"
    fields_desc = [
        ShortField("sink", 0),
        ShortField("reserved", 0)
    ]

class Padding(Packet):
    name = "Padding"
    fields_desc = [
        IntField("w0", 0),
        IntField("w1", 0),
        IntField("w2", 0),
        IntField("w3", 0),
        IntField("w4", 0),
        IntField("w5", 0),
        IntField("w6", 0),
        IntField("w7", 0)
    ]

class Data(Packet):
    name = "Data"
    fields_desc = [
        IntField("w0",  0x01020304 ),
        IntField("w1",  0x05060708 ),
        IntField("w2",  0x09101112 ),
        IntField("w3",  0x13141516 ),
        IntField("w4",  0x17181920 ),
        IntField("w5",  0x21222324 ),
        IntField("w6",  0x25262728 ),
        IntField("w7",  0x29303132 ),
        IntField("w8",  0x33343536 ),
        IntField("w9",  0x37383940 ),
        IntField("w10", 0x41424344 ),
        IntField("w11", 0x45464748 ),
        IntField("w12", 0x49505152 ),
        IntField("w13", 0x53545556 ),
        IntField("w14", 0x57585960 ),
        IntField("w15", 0x61626364 )
    ]

bind_layers(Ether, Tilelink, type=TILELINK_TYPE)
bind_layers(Ether, Credit,   type=TILELINK_TYPE, channel=CHANNEL_F)

def handle(pkt):
    pkt.show()

MAC_SRC = "0a:0b:0c:01:02:03"
MAC_DST = "0a:0b:0c:0d:0e:0f"

def send_tilelink_packet(args):
    put_msg = Ether(dst=MAC_DST, src=MAC_SRC) / Tilelink(channel=CHANNEL_A, opcode=0, m_size=2, domain=4) / Address(hi_addr=0x2, lo_addr=0x20000004) / ("\x01\x2c\x70\x40\x03\x04\x05\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
    get_msg = Ether(dst=MAC_DST, src=MAC_SRC) / Tilelink(channel=CHANNEL_A, opcode=4, m_size=2, domain=2) / Address(hi_addr=0x2, lo_addr=0x20000004) / ("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
    put_msg2 = Ether(dst=MAC_DST, src=MAC_SRC) / Tilelink(channel=CHANNEL_A, opcode=0, m_size=6, domain=4) / Address(hi_addr=0x2, lo_addr=0x28000000) / Data()
    get_msg2 = Ether(dst=MAC_DST, src=MAC_SRC) / Tilelink(channel=CHANNEL_A, opcode=4, m_size=6, domain=2) / Address(hi_addr=0x2, lo_addr=0x28000000) / Padding()
    acquire_msg = Ether(dst=MAC_DST, src=MAC_SRC) / Tilelink(channel=CHANNEL_A, opcode=6, m_size=6, domain=2) / Address(hi_addr=0x2, lo_addr=0x28000000) / Padding()

    pkts = [put_msg, get_msg, put_msg2, get_msg2, acquire_msg]
    sendp(pkts, iface=args.iface)



if __name__=='__main__':
    parser = argparse.ArgumentParser(description='Craft TileLink messages.')
    parser.add_argument('--iface', help='sniffing interface')
    parser.add_argument('--client', help='function as a client', action="store_true")
    parser.add_argument('--put', help='send put request')
    parser.add_argument('--pcap', help='read from pcap')

    args = parser.parse_args()

    if args.pcap:
        pkts = rdpcap(args.pcap)
        for p in pkts:
            p.show()
        sendp(pkts, iface=args.iface)

    else:
        if args.client:
            send_tilelink_packet(args)
        else:
            if args.iface:
                filter_str = 'ether proto %s' % TILELINK_TYPE
                sniff(iface=args.iface, filter=filter_str, prn=lambda x: handle(x))
            else:
                print("Expected interface name")
