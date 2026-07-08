class statistics;
 
  static virtual eth_ui_interface v_uif[bit[47:0]];
 
  //pause
  static int  pause_value [bit[47:0]];
  static bit  pause_flag  [bit [47:0]];
  static bit  pause_update[bit [47:0]];
 
  //pfc
  static int  pfc_value   [bit [47:0]][8];
  static bit  pfc_flag    [bit [47:0]][8];
  static bit  pfc_update  [bit [47:0]][8];

  //tx_pending[bit[47:0]]ers;
  static int tx_good_pkt_pending [bit[47:0]];
  static int tx_bad_pkt_pending  [bit[47:0]];
  static int tx_collision_pending [bit[47:0]];
  static int tx_unicast_pending [bit[47:0]];
  static int tx_multicast_pending [bit[47:0]];
  static int tx_broadcast_pending [bit[47:0]];
  static int tx_runt_pending [bit[47:0]];
  static int tx_fragment_pending [bit[47:0]];
  static int tx_jumbo_pending [bit[47:0]];
  static int tx_super_jumbo_pending [bit[47:0]];
  static int tx_jabber_pending [bit[47:0]];
  static int tx_pause_pending [bit[47:0]];
  static int tx_vlan_pending [bit[47:0]];
  static int tx_ipg_violation_pending [bit[47:0]];
  static int tx_pfc_xon_pending [bit[47:0]];
  static int tx_pfc_xoff_pending [bit[47:0]];
  static int tx_carrier_ext_pending [bit[47:0]];
  static int tx_pause_xon_pending [bit[47:0]]; 
  static int tx_pause_xoff_pending [bit[47:0]];
  static int tx_control_pkt_pending [bit[47:0]];
  static int tx_pfc_xon_prio0_pending[bit[47:0]];
  static int tx_pfc_xon_prio1_pending[bit[47:0]];
  static int tx_pfc_xon_prio2_pending[bit[47:0]];
  static int tx_pfc_xon_prio3_pending[bit[47:0]];
  static int tx_pfc_xon_prio4_pending[bit[47:0]];
  static int tx_pfc_xon_prio5_pending[bit[47:0]];
  static int tx_pfc_xon_prio6_pending[bit[47:0]];
  static int tx_pfc_xon_prio7_pending[bit[47:0]];
  static int tx_pfc_xoff_prio0_pending[bit[47:0]];
  static int tx_pfc_xoff_prio1_pending[bit[47:0]];
  static int tx_pfc_xoff_prio2_pending[bit[47:0]];
  static int tx_pfc_xoff_prio3_pending[bit[47:0]];
  static int tx_pfc_xoff_prio4_pending[bit[47:0]];
  static int tx_pfc_xoff_prio5_pending[bit[47:0]];
  static int tx_pfc_xoff_prio6_pending[bit[47:0]];
  static int tx_pfc_xoff_prio7_pending[bit[47:0]];
  
  //Rx C int
  static int rx_good_pkt_pending [bit[47:0]];
  static int rx_bad_pkt_pending [bit[47:0]];
  static int rx_collision_pending [bit[47:0]];
  static int rx_unicast_pending [bit[47:0]];
  static int rx_multicast_pending [bit[47:0]];
  static int rx_broadcast_pending [bit[47:0]];
  static int rx_runt_pending [bit[47:0]];
  static int rx_fragment_pending [bit[47:0]];
  static int rx_jumbo_pending [bit[47:0]];
  static int rx_super_jumbo_pending [bit[47:0]];
  static int rx_jabber_pending [bit[47:0]];
  static int rx_pause_pending [bit[47:0]];
  static int rx_vlan_pending [bit[47:0]];
  static int rx_drop_pending [bit[47:0]];
  static int rx_ipg_violation_pending [bit[47:0]];
  static int rx_pfc_xon_pending [bit[47:0]];
  static int rx_pfc_xoff_pending [bit[47:0]];
  static int rx_carrier_ext_pending [bit[47:0]];
  static int rx_pause_xon_pending [bit[47:0]]; 
  static int rx_pause_xoff_pending [bit[47:0]];
  static int rx_control_pkt_pending [bit[47:0]];
  static int rx_pfc_xon_prio0_pending[bit[47:0]];
  static int rx_pfc_xon_prio1_pending[bit[47:0]];
  static int rx_pfc_xon_prio2_pending[bit[47:0]];
  static int rx_pfc_xon_prio3_pending[bit[47:0]];
  static int rx_pfc_xon_prio4_pending[bit[47:0]];
  static int rx_pfc_xon_prio5_pending[bit[47:0]];
  static int rx_pfc_xon_prio6_pending[bit[47:0]];
  static int rx_pfc_xon_prio7_pending[bit[47:0]];
  static int rx_pfc_xoff_prio0_pending[bit[47:0]];
  static int rx_pfc_xoff_prio1_pending[bit[47:0]];
  static int rx_pfc_xoff_prio2_pending[bit[47:0]];
  static int rx_pfc_xoff_prio3_pending[bit[47:0]];
  static int rx_pfc_xoff_prio4_pending[bit[47:0]];
  static int rx_pfc_xoff_prio5_pending[bit[47:0]];
  static int rx_pfc_xoff_prio6_pending[bit[47:0]];
  static int rx_pfc_xoff_prio7_pending[bit[47:0]];

endclass
