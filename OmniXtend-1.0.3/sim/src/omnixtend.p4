/*
 * Copyright 2019-present Western Digital Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: Tu Dang (tu.dang@wdc.com)
 */

#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_ARP = 0x806;
const bit<16> TYPE_OMNIXTEND = 0x870;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

/* omnixtend Types */
typedef bit<3> channel_t;
typedef bit<3> opcode_t;
typedef bit<4> param_t;
typedef bit<26> source_t;
typedef bit<64> memAddr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

#define RTE_ARP_HRD_ETHER     1
#define RTE_ARP_OP_REQUEST    1 /* request to resolve address */
#define RTE_ARP_OP_REPLY      2 /* response to previous request */
#define RTE_ARP_OP_REVREQUEST 3 /* request proto addr given hardware */
#define RTE_ARP_OP_REVREPLY   4 /* response giving protocol address */
#define RTE_ARP_OP_INVREQUEST 8 /* request to identify peer */
#define RTE_ARP_OP_INVREPLY   9 /* response identifying peer */

header arp_t {
    bit<16> arp_hardware;
    bit<16> arp_protocol;
    bit<8> arp_hlen;
    bit<8> arp_plen;
    bit<16> arp_opcode;
    macAddr_t sender_ha;
    ip4Addr_t sender_ip;
    macAddr_t target_ha;
    ip4Addr_t target_ip;
}

header flow_control_t {
    bit<3> vc;
    bit<7> r1;
    bit<22> seq;
    bit<22> seq_ack;
    bit<1> ack;
    bit<1> r2;
    bit<3> chan;
    bit<5> credit;
}

header omnixtend_t {
	bit<1> r1;
    channel_t channel;
    opcode_t opcode;
	bit<1> r2;
    param_t param;
    bit<4> msg_size;
    bit<8> domain;
	bit<6> r3;
    bit<2> err;
    bit<6> r4;
    source_t source;
}

header sink_t {
    bit<26> sink;
    bit<38> r5;
}


header mem_address_t {
    bit<32> hi_addr;
    bit<32> lo_addr;
}


header data_mask_t {
    bit<32> hi_mask;
    bit<32> lo_mask;
}
header data_t {
    bit<32> w0;
    bit<32> w1;
    bit<32> w2;
    bit<32> w3;
    bit<32> w4;
    bit<32> w5;
    bit<32> w6;
    bit<32> w7;
    bit<32> w8;
    bit<32> w9;
    bit<32> w10;
    bit<32> w11;
    bit<32> w12;
    bit<32> w13;
    bit<32> w14;
    bit<32> w15;
}

typedef bit<4> index_t;
typedef bit<2> state_t;
typedef bit<16> owner_t;
struct metadata {
    /* empty */
    bit<1> cache_valid;
    index_t cache_index;
    state_t cache_state;
    owner_t cache_owner;
}

struct headers {
    ethernet_t      ethernet;
    arp_t           arp;
    flow_control_t  flow_control;
    omnixtend_t     omnixtend;
    sink_t          sink;
    mem_address_t   address;
    data_mask_t     data_mask;
    data_t          data;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_ARP : parse_arp;
            TYPE_OMNIXTEND : parse_omnixtend;
            default : accept;
        }
    }

    state parse_arp {
        packet.extract(hdr.arp);
        transition accept;
    }

    state parse_omnixtend {
        packet.extract(hdr.flow_control);
        packet.extract(hdr.omnixtend);
        transition select(hdr.omnixtend.channel, hdr.omnixtend.opcode) {
            (1,6) : parse_address;
            (4,4) : parse_sink;
            (4,5) : parse_sink_data;
            (2,6) : parse_address;
            (3,4) : parse_address;
            default : accept;
        }
    }

    state parse_address {
        packet.extract(hdr.address);
        transition accept;
    }

    state parse_sink {
        packet.extract(hdr.sink);
        transition accept;
    }

    state parse_sink_data {
        packet.extract(hdr.sink);
        packet.extract(hdr.data);
        transition accept;
    }

}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    @name("valid_reg") register<bit<1>>(16) valid_reg;
    @name("state_reg") register<state_t>(2) state_reg;  // Invalid / Shared / Owned
    @name("owner_reg") register<owner_t>(16) owner_reg;             // Owner node
    @name("src_reg") register<index_t>(16) src_reg;

    action drop() {
        mark_to_drop(standard_metadata);
    }

    action broadcast() {
        standard_metadata.mcast_grp = 1;
    }

    action mac_forward(egressSpec_t port) {
        standard_metadata.egress_spec = port;
    }

    action redirect(macAddr_t dst_mac) {
        hdr.ethernet.dstAddr = dst_mac;
    }

    table mac_lookup {
        key = {
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            broadcast;
            mac_forward;
            drop;
        }
        size = 1024;
        default_action = broadcast;
    }

    action compute_index() {
        hash(meta.cache_index,
            HashAlgorithm.crc16,
            (index_t)0,
            { hdr.address.hi_addr, hdr.address.lo_addr },
            (index_t)15);
    }

    action get_index_from_src() {
        src_reg.read(meta.cache_index, (bit<32>)hdr.omnixtend.source);
    }

    action set_index() {
        src_reg.write((bit<32>)hdr.omnixtend.source, meta.cache_index);
    }

    action get_valid_bit() {
        valid_reg.read(meta.cache_valid, (bit<32>) meta.cache_index);
    }

    action set_valid_bit() {
        valid_reg.write((bit<32>) meta.cache_index, (bit<1>)1);
    }

    action get_cache_owner() {
        owner_reg.read(meta.cache_owner, (bit<32>) meta.cache_index);
    }

    action set_cache_owner() {
        owner_reg.write((bit<32>) meta.cache_index, (owner_t)hdr.omnixtend.source);
    }

    action respond_same_size(channel_t new_chan, opcode_t new_op, param_t new_param) {
        hdr.omnixtend.channel = new_chan;
        hdr.omnixtend.opcode = new_op;
        hdr.omnixtend.param = new_param;
    }

    action handle_acquire() {
        compute_index();
        set_index();
        get_valid_bit();
        get_cache_owner();
    }

    action handle_grant() {
        get_index_from_src();
        set_cache_owner();
    }

    action handle_release() {
        compute_index();
        get_valid_bit();
    }

    action handle_release_data() {
        compute_index();
        get_valid_bit();
    }

    table omni_exact {
        key = {
            hdr.omnixtend.channel : exact;
            hdr.omnixtend.opcode : exact;
        }
        actions = {
            handle_acquire;
            respond_same_size;
            handle_grant;
            handle_release;
            handle_release_data;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction;
    }


    table owner_tbl {
        key = {
            meta.cache_owner : exact;
         }
         actions = {
             redirect;
             NoAction;
         }
         size = 1024;
         default_action = NoAction();
    }

    apply {
        if (hdr.omnixtend.isValid()) {
            omni_exact.apply();
            owner_tbl.apply();
        }
        if (hdr.ethernet.isValid())
            mac_lookup.apply();
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

    apply {
        if (standard_metadata.egress_port == standard_metadata.ingress_port)
            drop();
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {

    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.arp);
        packet.emit(hdr.flow_control);
        packet.emit(hdr.omnixtend);
        packet.emit(hdr.sink);
        packet.emit(hdr.address);
        packet.emit(hdr.data_mask);
        packet.emit(hdr.data);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
