# Register map:
#	chip0	chip1
#RX:	0x30000	0x200030000 VC0
#	0x30080 0x200030080 VC1
#				0  = header strip size (14)	0xE
#				8  = match mask        (14)	0x3FFF
#				64 = header bytes
#TX:	0x20000	0x200020000 VC0
#	0x20080 0x200020080 VC1
#				0  = header insert size (14)	0xE
#				64 = header to add

# Goal:
# chip0 VC0 MAC = 68:05:CA:88:3D:01
# chip0 VC1 MAC = 68:05:CA:88:3D:02
# chip1 VC0 MAC = 68:05:CA:88:3D:03
# chip1 VC1 MAC = 68:05:CA:88:3D:04
# ethertype = AAAA

# <6 bytes dest> <6 bytes source> <2 bytes type>
# SSSS DDDD DDDD DDDD = 0568 0x3D 88CA 0568
# 0000 EEEE SSSS SSSS = 0000 AAAA 0x3D 88CA

# chip1vc0 (3) -> chip0vc0 (1)
devmem     0x30008 64 0x00FF             # chip0vc0 RX: match only 1 bytes of dest MAC
devmem 0x200020048 64 0x0000AAAA033D88CA # chip1vc0 TX: set ethertype + 4 bytes of source MAC
devmem     0x30048 64 0x0000AAAA033D88CA # chip0vc0 RX: set ethertype + 4 bytes of source MAC
devmem     0x30008 64 0x3F00             # chip0vc0 RX: match sender
devmem 0x200020040 64 0x0568013D88CA0568 # chip1vc0 TX: set dest MAC + 2 bytes of source MAC
devmem     0x30040 64 0x0568013D88CA0568 # chip0vc0 RX: set dest MAC + 2 bytes of source MAC
devmem     0x30008 64 0x3FFF             # chip0vc0 RX: match sender+dest+ethertype

# chip1vc1 (4) -> chip0vc1 (2)
devmem     0x30088 64 0x00FF             # chip0vc1 RX: match only 1 bytes of dest MAC
devmem 0x2000200C8 64 0x0000AAAA043D88CA # chip1vc1 TX: set ethertype + 4 bytes of source MAC
devmem     0x300C8 64 0x0000AAAA043D88CA # chip0vc1 RX: set ethertype + 4 bytes of source MAC
devmem     0x30088 64 0x3F00             # chip0vc1 RX: match sender
devmem 0x2000200C0 64 0x0568023D88CA0568 # chip1vc1 TX: set dest MAC + 2 bytes of source MAC
devmem     0x300C0 64 0x0568023D88CA0568 # chip0vc1 RX: set dest MAC + 2 bytes of source MAC
devmem     0x30088 64 0x3FFF             # chip0vc1 RX: match sender+dest+ethertype

# chip0vc0 (1) -> chip1vc0 (3)
devmem 0x200030008 64 0x00FF             # chip1vc0 RX: match only 1 bytes of dest MAC
devmem     0x20048 64 0x0000AAAA013D88CA # chip0vc0 TX: set ethertype + 4 bytes of source MAC
devmem 0x200030048 64 0x0000AAAA013D88CA # chip1vc0 RX: set ethertype + 4 bytes of source MAC
devmem 0x200030008 64 0x3F00             # chip1vc0 RX: match sender
devmem     0x20040 64 0x0568033D88CA0568 # chip0vc0 TX: set dest MAC + 2 bytes of source MAC
devmem 0x200030040 64 0x0568033D88CA0568 # chip1vc0 RX: set dest MAC + 2 bytes of source MAC
devmem 0x200030008 64 0x3FFF             # chip1vc0 RX: match sender+dest+ethertype

# chip0vc1 (2) -> chip1vc1 (4)
devmem 0x200030088 64 0x00FF             # chip1vc1 RX: match only 1 bytes of dest MAC
devmem     0x200C8 64 0x0000AAAA023D88CA # chip0vc1 TX: set ethertype + 4 bytes of source MAC
devmem 0x2000300C8 64 0x0000AAAA023D88CA # chip1vc1 RX: set ethertype + 4 bytes of source MAC
devmem 0x200030088 64 0x3F00             # chip1vc1 RX: match sender
devmem     0x200C0 64 0x0568043D88CA0568 # chip0vc1 TX: set dest MAC + 2 bytes of source MAC
devmem 0x2000300C0 64 0x0568043D88CA0568 # chip1vc1 RX: set dest MAC + 2 bytes of source MAC
devmem 0x200030088 64 0x3FFF             # chip1vc1 RX: match sender+dest+ethertype
