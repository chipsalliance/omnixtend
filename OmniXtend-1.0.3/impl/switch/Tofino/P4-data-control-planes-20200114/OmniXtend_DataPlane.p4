/* -*- P4_14 -*- */
#ifdef __TARGET_TOFINO__
#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>
#include <tofino/primitives.p4>
#else
#error This program is intended to compile for Tofino P4 architecture only
#endif

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/
header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}
header_type TLoE_t {
    fields {
       credit : 4;
       chan : 3;
       res1 : 1;
       ack : 1;
       sqnumack : 22;
       seqnum : 22;
       res2 : 7;
       vc : 3;
    }
}
header_type omnixtend_type1_t {
    fields {
       source :26;
       res1 : 12;
       error: 2;
       domain : 8;
       siz : 4;
       param : 4;
       res2 : 1;
       opcode : 3;
       chan : 3;
       res3 : 1;
       Addr : 64;
    }
}


header_type omnixtend_type2_t {
    fields {
       source :26;
       res1 : 12;
       error: 2;
       domain : 8;
       siz : 4;
       param : 4;
       res2 : 1;
       opcode : 3;
       chan : 3;
       res3 : 1;
    }
}

header_type omnixtend_type3_t {
    fields {
       source :26;
       res1 : 12;
       error: 2;
       domain : 8;
       siz : 4;
       param : 4;
       res2 : 1;
       opcode : 3;
       chan : 3;
       res3 : 1;
       sink : 26;
       res4 : 38;
    }
}

header_type omnixtend_type4_t {
    fields {
       sink : 26;
       res1 : 34;
       chan : 3;
       res2 : 1;
    }
}

header_type padding_t {
    fields {
        b0 : 8;
        b1 : 8;
        b2 : 8;
        b3 : 8;
        b4 : 8;
        b5 : 8;
        b6 : 8;
        b7 : 8;
    }
}

header_type TLoE_mask_t {
    fields {
        w1 : 64;
    }
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/

header ethernet_t ethernet;
header TLoE_t TLoE;
header omnixtend_type1_t omnixtend_type1;
header omnixtend_type2_t omnixtend_type2;
header omnixtend_type3_t omnixtend_type3;
header omnixtend_type4_t omnixtend_type4;
header padding_t padding;
header TLoE_mask_t TLoE_mask;

parser start {
    extract(ethernet);
    return ingress;
}


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
action send(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

action discard() {
    modify_field(ig_intr_md_for_tm.drop_ctl, 1);
}


table omnixtend_host{
    reads {
         ig_intr_md.ingress_port : exact;
    }
    actions {
        send;
        discard;
    }
    size : 64;
}


control ingress {
       apply(omnixtend_host);

}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control egress {
}





