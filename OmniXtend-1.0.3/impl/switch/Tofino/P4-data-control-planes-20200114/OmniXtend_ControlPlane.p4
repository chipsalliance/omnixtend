
#simple table setup script for OmniXtend_DataPlane.p4
#

clear_all()

p4_pd.omnixtend_host_table_add_with_send(p4_pd.omnixtend_host_match_spec_t(ig_intr_md_ingress_port=8),p4_pd.send_action_spec_t(24))
p4_pd.omnixtend_host_table_add_with_send(p4_pd.omnixtend_host_match_spec_t(ig_intr_md_ingress_port=24),p4_pd.send_action_spec_t(8))



conn_mgr.complete_operations()
