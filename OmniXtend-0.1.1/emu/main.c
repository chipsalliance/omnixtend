/* SPDX-License-Identifier: BSD-3-Clause
* Copyright(c) 2010-2015 Intel Corporation
*
*   Author: Huynh Tu Dang
*/

#include <stdint.h>
#include <math.h>
#include <inttypes.h>
#include <arpa/inet.h>
#include <getopt.h>

#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_malloc.h>
#include <rte_memcpy.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <rte_icmp.h>
#include <rte_tcp.h>
#include <rte_udp.h>
#include <rte_arp.h>
#include <rte_log.h>
#include <rte_hexdump.h>

#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024

#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32

#define RTE_LOGTYPE_OMNIX RTE_LOGTYPE_USER1
#define RTE_ETHER_TYPE_OMNIX	0x0000
#define RTE_ETHER_TYPE_OMNIX2	0x0870
#define MEMORY_SIZE 2147483648
// #define MEMORY_SIZE 4294967296

#define PACKET_MIN_SIZE

#define CHANNEL_A 0
#define CHANNEL_B 1
#define CHANNEL_C 2
#define CHANNEL_D 3
#define CHANNEL_E 4
#define CHANNEL_F 5

struct omnix_hdr {
	uint16_t channel : 3;
	uint16_t opcode : 3;
	uint16_t parm : 3;
	uint16_t m_size : 4;
	uint16_t domain : 3;
	uint16_t source;
}  __attribute__((__packed__));


struct credit_hdr {
	uint32_t channel : 3;
	uint32_t zeros : 4;
	uint32_t a : 5;
	uint32_t b : 5;
	uint32_t c : 5;
	uint32_t d : 5;
	uint32_t e : 5;
} __attribute__((__packed__));

struct mem_addr {
	uint32_t hi_addr;
	uint32_t lo_addr;
} __attribute__((__packed__));

struct grant_hdr {
	uint16_t reserved;
	uint16_t sink;
} __attribute__((__packed__));


static char *mem;

static int dump_probe;

// static const char fixed_data[64] = {
// 					0x00, 0x2c, 0x70, 0x00, 0x00, 0x00, 0x00, 0x20,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33,
// 					0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33, 0x33 };

static struct sockaddr_in my_ip_addr;

static const struct rte_eth_conf port_conf_default = {
	.rxmode = {
		.max_rx_pkt_len = RTE_ETHER_MAX_LEN,
	},
};

static struct {
	uint64_t total_cycles;
	uint64_t total_pkts;
} latency_numbers;

static int arp_handler(uint16_t port, struct rte_mbuf *pkt) {
	struct rte_ether_hdr *eth_hdr;
	struct rte_arp_hdr *arp_hdr;
	struct rte_ether_addr d_addr;
	char src[INET_ADDRSTRLEN];
	char dst[INET_ADDRSTRLEN];
	size_t ip_offset;

	eth_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_ether_hdr *, 0);
	ip_offset = sizeof(struct rte_ether_hdr);
	arp_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_arp_hdr *, ip_offset);
	RTE_LOG(DEBUG, OMNIX, "src=%hx dst=%hx\n", my_ip_addr.sin_addr.s_addr,
	arp_hdr->arp_data.arp_tip);
	inet_ntop(AF_INET, &(arp_hdr->arp_data.arp_sip), src, INET_ADDRSTRLEN);
	inet_ntop(AF_INET, &(arp_hdr->arp_data.arp_tip), dst, INET_ADDRSTRLEN);
	RTE_LOG(DEBUG, OMNIX, "ARP: %s -> %s\n", src, dst);
	if (arp_hdr->arp_data.arp_tip != my_ip_addr.sin_addr.s_addr)
	return -1;

	if (arp_hdr->arp_opcode != rte_cpu_to_be_16(RTE_ARP_OP_REQUEST))
	return -1;

	RTE_LOG(DEBUG, OMNIX, "ARP Request\n");
	arp_hdr->arp_opcode = rte_cpu_to_be_16(RTE_ARP_OP_REPLY);
	/* Switch src and dst data and set bonding MAC */
	rte_ether_addr_copy(&eth_hdr->s_addr, &eth_hdr->d_addr);
	rte_eth_macaddr_get(port, &eth_hdr->s_addr);
	rte_ether_addr_copy(&arp_hdr->arp_data.arp_sha, &arp_hdr->arp_data.arp_tha);
	arp_hdr->arp_data.arp_tip = arp_hdr->arp_data.arp_sip;
	rte_eth_macaddr_get(port, &d_addr);
	rte_ether_addr_copy(&d_addr, &arp_hdr->arp_data.arp_sha);
	arp_hdr->arp_data.arp_sip = my_ip_addr.sin_addr.s_addr;

	return 0;
}

static int ipv4_handler(uint16_t port, struct rte_mbuf *pkt) {
	struct rte_ether_hdr *eth_hdr;
	struct rte_ipv4_hdr *ipv4_hdr;
	// struct rte_udp_hdr *udp_hdr;
	struct rte_icmp_hdr *icmp_hdr;
	uint32_t cksum;
	size_t ip_offset;
	char src[INET_ADDRSTRLEN];
	char dst[INET_ADDRSTRLEN];
	eth_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_ether_hdr *, 0);
	ip_offset = sizeof(struct rte_ether_hdr);
	ipv4_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_ipv4_hdr *, ip_offset);
	size_t l4_offset = ip_offset + sizeof(struct rte_ipv4_hdr);
	inet_ntop(AF_INET, &(ipv4_hdr->src_addr), src, INET_ADDRSTRLEN);
	inet_ntop(AF_INET, &(ipv4_hdr->dst_addr), dst, INET_ADDRSTRLEN);

	RTE_LOG(DEBUG, OMNIX, "IPv4: %s -> %s\n", src, dst);

	switch (ipv4_hdr->next_proto_id) {
		case IPPROTO_UDP:
		// udp_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_udp_hdr *, l4_offset);
		RTE_LOG(DEBUG, OMNIX, "UDP hander not implemented yet\n");
		return -1;
		case IPPROTO_ICMP:
		icmp_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_icmp_hdr *, l4_offset);
		RTE_LOG(DEBUG, OMNIX, "ICMP: %s -> %s: Type: %02x\n", src, dst, icmp_hdr->icmp_type);
		if (icmp_hdr->icmp_type == RTE_IP_ICMP_ECHO_REQUEST) {
			if (ipv4_hdr->dst_addr == my_ip_addr.sin_addr.s_addr) {
				icmp_hdr->icmp_type = RTE_IP_ICMP_ECHO_REPLY;
				rte_ether_addr_copy(&eth_hdr->s_addr, &eth_hdr->d_addr);
				rte_eth_macaddr_get(port, &eth_hdr->s_addr);
				ipv4_hdr->dst_addr = ipv4_hdr->src_addr;
				ipv4_hdr->src_addr = my_ip_addr.sin_addr.s_addr;
				cksum = ~icmp_hdr->icmp_cksum & 0xffff;
				cksum += ~htons(RTE_IP_ICMP_ECHO_REQUEST << 8) & 0xffff;
				cksum += htons(RTE_IP_ICMP_ECHO_REPLY << 8);
				cksum = (cksum & 0xffff) + (cksum >> 16);
				cksum = (cksum & 0xffff) + (cksum >> 16);
				icmp_hdr->icmp_cksum = ~cksum;
				return 0;
			}
		}
		return -1;
	}
	return -1;
}

static void show_omni_hdr(struct omnix_hdr *omnix, struct mem_addr *mem_addr)
{

	RTE_LOG(INFO, OMNIX, "Channel %u Opcode %u Param %u Domain %u Size %u Source %u\n",
											omnix->channel, omnix->opcode, omnix->parm, omnix->domain,
											omnix->m_size, omnix->source);
	if (mem_addr) {
		RTE_LOG(INFO, OMNIX, "Address 0x%08x 0x%08x\n",
													rte_be_to_cpu_32(mem_addr->hi_addr),
													rte_be_to_cpu_32(mem_addr->lo_addr));
	}
}

static void __rte_unused show_credit(struct credit_hdr *credit)
{
	RTE_LOG(DEBUG, OMNIX, "Channel %u ", credit->channel);
	RTE_LOG(DEBUG, OMNIX, "zeros %u ", credit->zeros);
	RTE_LOG(DEBUG, OMNIX, "a %u ", credit->a);
	RTE_LOG(DEBUG, OMNIX, "b %u ", credit->b);
	RTE_LOG(DEBUG, OMNIX, "c %u ", credit->c);
	RTE_LOG(DEBUG, OMNIX, "d %u ", credit->d);
	RTE_LOG(DEBUG, OMNIX, "e %u\n", credit->e);
}


static int omnix_handler(uint16_t port, struct rte_mbuf *pkt) {
	struct rte_ether_hdr *eth_hdr;
	struct omnix_hdr *omni_hdr;
	struct mem_addr *mem_addr;

	uint32_t offset;
	eth_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_ether_hdr *, 0);
	rte_eth_macaddr_get(port, &eth_hdr->s_addr);
	offset = sizeof(struct rte_ether_hdr) + 2;

	int *omni_pt = rte_pktmbuf_mtod_offset(pkt, int *, offset);
	*omni_pt = rte_be_to_cpu_32(*omni_pt);
	omni_hdr = (struct omni_hdr *)omni_pt;

	if (omni_hdr->channel == CHANNEL_F) {
		struct credit_hdr *credit = (struct credit_hdr *)omni_pt;
		show_credit(credit);
		credit->a = 12;
		credit->b = 12;
		credit->c = 12;
		credit->d = 12;
		credit->e = 12;
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_B && omni_hdr->opcode == 6) {
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		omni_hdr->channel = CHANNEL_C;
		omni_hdr->opcode = 4;
		omni_hdr->parm = 5; // NtoN
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_A && omni_hdr->opcode == 4) {
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		show_omni_hdr(omni_hdr, mem_addr);
		omni_hdr->channel = CHANNEL_D;
		omni_hdr->opcode = 1;
		omni_hdr->parm = 0;
		uint32_t read_index = rte_be_to_cpu_32(mem_addr->lo_addr);
		uint32_t read_size = (int) pow((double) 2,omni_hdr->m_size);
		// Reset
		mem_addr->hi_addr = 0;
		mem_addr->lo_addr = 0;
		uint32_t data_offset = offset + sizeof(omni_hdr);
		char *data = rte_pktmbuf_mtod_offset(pkt, char *, data_offset);
		rte_memcpy(data, mem + read_index, read_size);
		if (read_size > 40) {
			pkt->pkt_len = pkt->data_len = 24 + read_size;
		}
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_A && omni_hdr->opcode == 0) {
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		show_omni_hdr(omni_hdr, mem_addr);
		omni_hdr->channel = CHANNEL_D;
		omni_hdr->opcode = 0;
		omni_hdr->parm = 0;
		uint32_t write_index = rte_be_to_cpu_32(mem_addr->lo_addr);
		uint32_t write_size = (int) pow((double) 2,omni_hdr->m_size);
		// Reset
		mem_addr->hi_addr = 0;
		mem_addr->lo_addr = 0;
		uint32_t data_offset = offset + sizeof(struct omnix_hdr) + sizeof(struct mem_addr);
		char *data = rte_pktmbuf_mtod_offset(pkt, char *, data_offset);
		rte_memcpy(mem + write_index, data, write_size);
		memset(data, 0, write_size);
		pkt->pkt_len = pkt->data_len = 60;
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_A && omni_hdr->opcode == 6) {
		rte_pktmbuf_dump(stdout, pkt, pkt->pkt_len);
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		show_omni_hdr(omni_hdr, mem_addr);
		omni_hdr->channel = CHANNEL_D;
		omni_hdr->opcode = 5;
		switch(omni_hdr->parm) {
			case 0: // NtoB
			omni_hdr->parm = 1; // toB
			break;
			case 1: // NtoT
			omni_hdr->parm = 0; // toT
			break;
			case 2: // BtoT
			omni_hdr->parm = 0; // toT
			break;
			default:
			RTE_LOG(WARNING, OMNIX, "Unknown Permision %u\n", omni_hdr->parm);
		}
		uint32_t acquire_index = rte_be_to_cpu_32(mem_addr->lo_addr);
		uint32_t acquire_size = (int) pow((double) 2,omni_hdr->m_size);
		RTE_LOG(INFO, OMNIX, "Acquire Index %0x, size %u\n", acquire_index, acquire_size);
		struct grant_hdr *grant_hdr;
		grant_hdr = rte_pktmbuf_mtod_offset(pkt, struct grant_hdr *, offset + sizeof(struct omnix_hdr));
		grant_hdr->reserved = 0;
		grant_hdr->sink = 0;
		int *grant_hdr_pt = (int *)grant_hdr;
		*grant_hdr_pt = rte_cpu_to_be_32(*grant_hdr_pt);
		uint32_t data_offset = offset + sizeof(struct omnix_hdr) + sizeof(struct grant_hdr);
		char *data = rte_pktmbuf_mtod_offset(pkt, char *, data_offset);
		rte_memcpy(data, mem + acquire_index, acquire_size);
		if (acquire_size > 36) {
			pkt->pkt_len = pkt->data_len = 24 + acquire_size;
		}
		show_omni_hdr(omni_hdr, NULL);
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		RTE_LOG(INFO, OMNIX, "After Acquire Processed\n");
		rte_pktmbuf_dump(stdout, pkt, pkt->pkt_len);
		return 0;
	}

	else if (omni_hdr->channel == CHANNEL_E && omni_hdr->opcode == 0) {
		show_omni_hdr(omni_hdr, NULL);
		dump_probe = 1;
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		rte_pktmbuf_dump(stdout, pkt, pkt->pkt_len);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_C && omni_hdr->opcode == 6) {
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		show_omni_hdr(omni_hdr, mem_addr);
		omni_hdr->channel = CHANNEL_D;
		omni_hdr->opcode = 6;
		omni_hdr->parm = 0;
		// Reset
		mem_addr->hi_addr = 0;
		mem_addr->lo_addr = 0;
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else if (omni_hdr->channel == CHANNEL_C && omni_hdr->opcode == 7) {
		mem_addr = rte_pktmbuf_mtod_offset(pkt, struct mem_addr *, offset + sizeof(struct omnix_hdr));
		show_omni_hdr(omni_hdr, mem_addr);
		omni_hdr->channel = CHANNEL_D;
		omni_hdr->opcode = 6;
		omni_hdr->parm = 0;
		uint32_t write_index = rte_be_to_cpu_32(mem_addr->lo_addr);
		uint32_t write_size = (int) pow((double) 2,omni_hdr->m_size);
		uint32_t data_offset = offset + sizeof(omni_hdr) + sizeof (struct mem_addr);
		char *data = rte_pktmbuf_mtod_offset(pkt, char *, data_offset);
		rte_memcpy(mem + write_index, data, write_size);
		memset(data, 0, write_size);
		pkt->pkt_len = pkt->data_len = 60;
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		return 0;
	}
	else {
		RTE_LOG(INFO, OMNIX, "Discard %s:%d\n", __FILE__, __LINE__);
		show_omni_hdr(omni_hdr, NULL);
		*omni_pt = rte_cpu_to_be_32(*omni_pt);
		rte_pktmbuf_dump(stdout, pkt, pkt->pkt_len);
		return -1;
	}

	return -1;

}

static int process_packet(uint16_t port, struct rte_mbuf *pkt) {
	struct rte_ether_hdr *eth_hdr;

	eth_hdr = rte_pktmbuf_mtod_offset(pkt, struct rte_ether_hdr *, 0);
	switch (rte_be_to_cpu_16(eth_hdr->ether_type)) {
		case RTE_ETHER_TYPE_ARP:
		return arp_handler(port, pkt);
		case RTE_ETHER_TYPE_IPV4:
		return ipv4_handler(port, pkt);
		case RTE_ETHER_TYPE_OMNIX:
		case RTE_ETHER_TYPE_OMNIX2:
		return omnix_handler(port, pkt);
		default:
		RTE_LOG(DEBUG, OMNIX, "Ether Proto: 0x%04x\n", rte_be_to_cpu_16(eth_hdr->ether_type));
		return -1;
	}
}

static uint16_t
add_timestamps(uint16_t port __rte_unused, uint16_t qidx __rte_unused,
	struct rte_mbuf **pkts, uint16_t nb_pkts,
	uint16_t max_pkts __rte_unused, void *_ __rte_unused)
{
	unsigned i;
	int ret = 0;
	uint64_t now = rte_rdtsc();
	uint16_t nb_rx = nb_pkts;
	for (i = 0; i < nb_rx; i++) {
		pkts[i]->udata64 = now;
		ret = process_packet(port, pkts[i]);
		if (ret < 0) {
			rte_pktmbuf_free(pkts[i]);
			nb_pkts--;
		}
	}
	return nb_pkts;
}

static uint16_t
calc_latency(uint16_t port __rte_unused, uint16_t qidx __rte_unused,
struct rte_mbuf **pkts, uint16_t nb_pkts, void *_ __rte_unused)
{
	uint64_t cycles = 0;
	uint64_t now = rte_rdtsc();
	unsigned i;

	for (i = 0; i < nb_pkts; i++)
	cycles += now - pkts[i]->udata64;
	latency_numbers.total_cycles += cycles;
	latency_numbers.total_pkts += nb_pkts;

	if (latency_numbers.total_pkts > (5 * 1000 * 1000ULL)) {
		printf("Latency = %"PRIu64" cycles\n",
		latency_numbers.total_cycles / latency_numbers.total_pkts);
		latency_numbers.total_cycles = latency_numbers.total_pkts = 0;
	}
	return nb_pkts;
}

/* Check the link status of all ports in up to 9s, and print them finally */
static void
check_all_ports_link_status(uint16_t port_num, uint32_t port_mask)
{
#define CHECK_INTERVAL 100 /* 100ms */
#define MAX_CHECK_TIME 90 /* 9s (90 * 100ms) in total */
	uint16_t portid;
	uint8_t count, all_ports_up, print_flag = 0;
	struct rte_eth_link link;
	uint32_t n_rx_queues, n_tx_queues;

	printf("\nChecking link status");
	fflush(stdout);
	for (count = 0; count <= MAX_CHECK_TIME; count++) {
		all_ports_up = 1;
		for (portid = 0; portid < port_num; portid++) {
			if ((port_mask & (1 << portid)) == 0)
				continue;
			n_rx_queues = 1;
			n_tx_queues = 1;
			if ((n_rx_queues == 0) && (n_tx_queues == 0))
				continue;
			memset(&link, 0, sizeof(link));
			rte_eth_link_get_nowait(portid, &link);
			/* print link status if flag set */
			if (print_flag == 1) {
				if (link.link_status)
					printf(
					"Port%d Link Up - speed %uMbps - %s\n",
						portid, link.link_speed,
				(link.link_duplex == ETH_LINK_FULL_DUPLEX) ?
					("full-duplex") : ("half-duplex\n"));
				else
					printf("Port %d Link Down\n", portid);
				continue;
			}
			/* clear all_ports_up flag if any link down */
			if (link.link_status == ETH_LINK_DOWN) {
				all_ports_up = 0;
				break;
			}
		}
		/* after finally printing all link status, get out */
		if (print_flag == 1)
			break;

		if (all_ports_up == 0) {
			printf(".");
			fflush(stdout);
			rte_delay_ms(CHECK_INTERVAL);
		}

		/* set the print_flag if all ports up or timeout */
		if (all_ports_up == 1 || count == (MAX_CHECK_TIME - 1)) {
			print_flag = 1;
			printf(" done\n");
		}
	}
}

/*
* Initialises a given port using global settings and with the rx buffers
* coming from the mbuf_pool passed as parameter
*/
static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool)
{
	struct rte_eth_conf port_conf = port_conf_default;
	const uint16_t rx_rings = 1, tx_rings = 1;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;
	struct rte_eth_dev_info dev_info;
	struct rte_eth_txconf txconf;

	if (!rte_eth_dev_is_valid_port(port))
	return -1;

	rte_eth_dev_info_get(port, &dev_info);
	if (dev_info.tx_offload_capa & DEV_TX_OFFLOAD_MBUF_FAST_FREE)
	port_conf.txmode.offloads |=
	DEV_TX_OFFLOAD_MBUF_FAST_FREE;

	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
	return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
	return retval;

	for (q = 0; q < rx_rings; q++) {
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
			rte_eth_dev_socket_id(port), NULL, mbuf_pool);
			if (retval < 0)
			return retval;
		}

		txconf = dev_info.default_txconf;
		txconf.offloads = port_conf.txmode.offloads;
		for (q = 0; q < tx_rings; q++) {
			retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), &txconf);
				if (retval < 0)
				return retval;
			}

	retval  = rte_eth_dev_start(port);
	if (retval < 0)
	return retval;

	check_all_ports_link_status(1, ~0x0);

	struct rte_ether_addr addr;

	rte_eth_macaddr_get(port, &addr);
	printf("Port %u MAC: %02"PRIx8" %02"PRIx8" %02"PRIx8
	" %02"PRIx8" %02"PRIx8" %02"PRIx8"\n",
	(unsigned)port,
	addr.addr_bytes[0], addr.addr_bytes[1],
	addr.addr_bytes[2], addr.addr_bytes[3],
	addr.addr_bytes[4], addr.addr_bytes[5]);

	rte_eth_promiscuous_enable(port);
	rte_eth_add_rx_callback(port, 0, add_timestamps, NULL);
	rte_eth_add_tx_callback(port, 0, calc_latency, NULL);


	return 0;
}

/*
* Main thread that does the work, reading from INPUT_PORT
* and writing to OUTPUT_PORT
*/
static  __attribute__((noreturn)) void
lcore_main(void)
{
	uint16_t port;

	RTE_ETH_FOREACH_DEV(port)
	if (rte_eth_dev_socket_id(port) > 0 &&
	rte_eth_dev_socket_id(port) !=
	(int)rte_socket_id())
	printf("WARNING, port %u is on remote NUMA node to "
	"polling thread.\n\tPerformance will "
	"not be optimal.\n", port);

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n",
	rte_lcore_id());
	for (;;) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, 0, bufs, BURST_SIZE);
				if (unlikely(nb_rx == 0))
				continue;

				const uint16_t nb_tx = rte_eth_tx_burst(port, 0, bufs, nb_rx);
			if (unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
				rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
}

static int
parse_arg_ip_address(const char *arg, struct sockaddr_in *addr)
{
	int ret;
	char* ip_and_port = strdup(arg);
	const char delim[2] = ":";
	char* token = strtok(ip_and_port, delim);
	addr->sin_family = AF_INET;
	if (token != NULL) {
		ret = inet_pton(AF_INET, token, &addr->sin_addr);
		if (ret == 0 || ret < 0) {
			return -1;
		}
	}
	token = strtok(NULL, delim);
	if (token != NULL) {
		uint32_t x;
		char* endpt;
		errno = 0;
		x = strtoul(token, &endpt, 10);
		if (errno != 0 || endpt == arg || *endpt != '\0') {
			return -2;
		}
		addr->sin_port = htons(x);
	}

	char *ip = inet_ntoa(addr->sin_addr);
	RTE_LOG(DEBUG, OMNIX, "SRC %s\n", ip);
	return 0;
}

static
int app_parse_args(int argc, char **argv)
{
	int opt, ret;
	char **argvopt;
	int option_index;
	char *prgname = argv[0];
	static struct option lgopts[] = {
		{"src", 1, 0, 0},
		{NULL, 0, 0, 0}
	};
	uint32_t argc_src = 0;
	argvopt = argv;

	while ((opt = getopt_long(argc, argvopt, "", lgopts, &option_index)) != EOF) {
		switch (opt) {
			case 0:
			if (!strcmp(lgopts[option_index].name, "src")) {
				argc_src = 1;
				ret = parse_arg_ip_address(optarg, &my_ip_addr);
				if (ret) {
					printf("Incorrect value for --src argument (%d)\n", ret);
					return -1;
				}
			}
			break;
			default:
			ret = -1;
		}
	}

	if (argc_src == 0)
	{
		ret = parse_arg_ip_address("192.168.4.96:12345", &my_ip_addr);
	}
	if (optind >= 0)
	argv[optind - 1] = prgname;

	ret = optind - 1;
	optind = 1; /* reset getopt lib */
	return ret;
}

/* Main function, does initialisation and calls the per-lcore functions */
int
main(int argc, char *argv[])
{
	struct rte_mempool *mbuf_pool;
	uint16_t nb_ports;
	uint16_t portid;

	/* init EAL */
	int ret = rte_eal_init(argc, argv);

	if (ret < 0)
	rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

	ret = app_parse_args(argc, argv);
	argc -= ret;
	argv += ret;

	rte_log_set_level(RTE_LOGTYPE_OMNIX, rte_log_get_global_level());

	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports < 1)
	rte_exit(EXIT_FAILURE, "Error: number of ports must be greater than 0\n");

	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL",
	NUM_MBUFS * nb_ports, MBUF_CACHE_SIZE, 0,
	RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
	if (mbuf_pool == NULL)
	rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/* initialize all ports */
	RTE_ETH_FOREACH_DEV(portid)
	if (port_init(portid, mbuf_pool) != 0)
	rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu8"\n",
	portid);

	if (rte_lcore_count() > 1)
	printf("\nWARNING: Too much enabled lcores - "
	"App uses only 1 lcore\n");

	mem = rte_malloc(NULL, MEMORY_SIZE, 0);
	if (!mem)
		rte_panic("malloc failed");
	/* call lcore_main on master core only */
	lcore_main();
	return 0;
}
