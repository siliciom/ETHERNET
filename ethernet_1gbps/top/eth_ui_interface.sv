interface eth_ui_interface();
  
  // Tx Counters
  logic [31:0] tx_good_pkt_count;
  logic [31:0] tx_bad_pkt_count;
  logic [31:0] tx_collison_count;
  logic [31:0] tx_unicast_count;
  logic [31:0] tx_multicast_count;
  logic [31:0] tx_broadcast_count;
  logic [31:0] tx_runt_count;
  logic [31:0] tx_fragment_count;
  logic [31:0] tx_jumbo_count;
  logic [31:0] tx_super_jumbo_count;
  logic [31:0] tx_jabber_count;
  logic [31:0] tx_pause_count;
  logic [31:0] tx_vlan_count;
  logic [31:0] tx_ipg_violation_count;
  logic [31:0] tx_pfc_count;
  
  //Rx Counters
  logic [31:0] rx_good_pkt_count;
  logic [31:0] rx_bad_pkt_count;
  logic [31:0] rx_unicast_count;
  logic [31:0] rx_multicast_count;
  logic [31:0] rx_broadcast_count;
  logic [31:0] rx_runt_count;
  logic [31:0] rx_fragment_count;
  logic [31:0] rx_jumbo_count;
  logic [31:0] rx_super_jumbo_count;
  logic [31:0] rx_jabber_count;
  logic [31:0] rx_pause_count;
  logic [31:0] rx_vlan_count;
  logic [31:0] rx_drop_count;
  logic [31:0] rx_ipg_violation_count;
  logic [31:0] rx_pfc_count;
  
endinterface

