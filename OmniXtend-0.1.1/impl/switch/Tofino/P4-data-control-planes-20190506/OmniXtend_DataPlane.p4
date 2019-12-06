* -*- P4_14 -*- */
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

header_type omnixtend_t {
    fields {
       padding : 128;
       format : 3;
       opcode : 3;
       param : 3;
       sizex : 4;
       domain : 3;
       source : 16;
    }
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
header omnixtend_t omnixtend;

parser start {
    extract(omnixtend);
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





