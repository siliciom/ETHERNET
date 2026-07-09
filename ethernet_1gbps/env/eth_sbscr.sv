`uvm_analysis_imp_decl(_ap_3)
`uvm_analysis_imp_decl(_ap_4)

class eth_sbscr extends uvm_subscriber#(eth_seq_item);
  `uvm_component_utils(eth_sbscr);
  bit [47:0] mac_addr;
  int rx_pause_xoff_cnt;
  int rx_pause_xon_cnt;
  int rx_pfc_xoff_cnt;
  int rx_pfc_xon_cnt;
  int rx_runt_good_fcs_cnt;
  int rx_runt_bad_fcs_cnt;
  int rx_jabber_cnt;
  int  rx_pfc_xon_prio0_count;
  int  rx_pfc_xon_prio1_count;
  int  rx_pfc_xon_prio2_count;
  int  rx_pfc_xon_prio3_count;
  int  rx_pfc_xon_prio4_count;
  int  rx_pfc_xon_prio5_count;
  int  rx_pfc_xon_prio6_count;
  int  rx_pfc_xon_prio7_count;
  int  rx_pfc_xoff_prio0_count;
  int  rx_pfc_xoff_prio1_count;
  int  rx_pfc_xoff_prio2_count;
  int  rx_pfc_xoff_prio3_count;
  int  rx_pfc_xoff_prio4_count;
  int  rx_pfc_xoff_prio5_count;
  int  rx_pfc_xoff_prio6_count;
  int  rx_pfc_xoff_prio7_count;
  
  uvm_analysis_imp_ap_3#(eth_seq_item, eth_sbscr) ai_1[`NO_OF_AGENTS];  //TX
  uvm_analysis_imp_ap_4#(eth_seq_item, eth_sbscr) ai_2[`NO_OF_AGENTS]; 
  eth_seq_item tr;
  covergroup ethernet_cg1;
    cp_sa : coverpoint tr.sa {bins unicast_addr[] = {48'h00_50_40_30_20_10, 48'h00_51_41_31_21_11, 48'h00_52_42_32_22_12, 48'h00_53_43_33_23_13};
  		            illegal_bins invalid_sa = default; }
  
    cp_da : coverpoint tr.da {bins dest_addr[] = {48'hFF_FF_FF_FF_FF_FF,48'h00_50_40_30_20_10, 48'h00_51_41_31_21_11, 48'h00_52_42_32_22_12,
  	                                        48'h00_53_43_33_23_13,48'h01_80_c2_00_00_01};
  	                    illegal_bins invalid_da = default;}
  
    cp_eth_type : coverpoint tr.ether_type {bins low_ether_type = {[46 : 500]};
  				     bins mid_ether_type = {[501 : 1000]};
  				     bins high_ether_type = {[1001 : 1500]}; }
    cp_vlan_type : coverpoint tr.TPID {bins vlan_type = {16'h8100};}
    cp_vlan       : coverpoint tr.vlan_en {bins vlan_enabled  = {1}; bins vlan_disabled = {0};}
    cp_vlan_pcp   : coverpoint tr.PCP iff(tr.vlan_en) {bins pcp[]={[0:7]};}
    cp_pause_xoff : coverpoint (rx_pause_xoff_cnt > 0) {bins no_pause_xoff_received = {0}; bins pause_xoff_received = {1};}
    cp_pause_xon  : coverpoint (rx_pause_xon_cnt > 0) {bins no_pause_xon_received = {0}; bins pause_xon_received = {1};}
    cp_pfc_xon    : coverpoint (rx_pfc_xon_cnt > 0) {bins no_pfc_xon_received  = {0}; bins pfc_xon_received  = {1};}
    cp_pfc_xoff   : coverpoint (rx_pfc_xoff_cnt > 0) {bins no_pfc_xoff_received = {0}; bins pfc_xoff_received = {1};}
    cp_payload : coverpoint tr.payload.size() {bins min_payload = {46};
                                               bins normal_payload = {[47:1499]};
    					       bins max_payload = {1500};
                                               illegal_bins invalid_payload_size ={[0:45],[1501:1535]};}
    cp_runt : coverpoint tr.payload.size() {bins runt = {[0:45]};} 	
    cp_duplex : coverpoint tr.mode {bins half_duplex = {0}; bins full_duplex = {1};}		 
    cp_invalid_sa : coverpoint (tr.sa == tr.da) {illegal_bins invalid_sa = {1};}
    cross_vlan_ether : cross cp_vlan,cp_vlan_type {bins valid_vlan = 
    	                                        binsof(cp_vlan_type.vlan_type) && binsof(cp_vlan.vlan_enabled);
    		                                illegal_bins invlaid_vlan = binsof(cp_vlan.vlan_disabled) && binsof(cp_vlan_type.vlan_type);}
    cp_ether_payload : coverpoint (tr.ether_type == tr.payload.size()) 
                         {bins match = {1};
    	                  illegal_bins mismatch = {0};}
    cp_crc_residue   : coverpoint tr.crc_residue {bins good_crc_residue = {32'hc704dd7b}; illegal_bins bad_crc_residue= default;}
  endgroup

  covergroup ethernet_cg2;
    option.per_instance = 1;
    cp_runt_frame : coverpoint (rx_runt_good_fcs_cnt>0) {bins no_runt_good_fcs_received ={0}; bins runt_good_fcs_received ={1};}
    cp_fragment_frame : coverpoint (rx_runt_bad_fcs_cnt>0){bins no_runt_bad_fcs_received ={0}; bins runt_bad_fcs_received ={1};}
    cp_jabber_frame : coverpoint (rx_jabber_cnt>0){bins no_jabber_received ={0}; bins jabber_received ={1};}
    cp_pfc_xoff_prio0 : coverpoint rx_pfc_xoff_prio0_count>0 {bins pfc_xoff_prio0_received ={1} ;bins no_pfc_xoff_prio0_received ={0} ;}
    cp_pfc_xoff_prio1 : coverpoint rx_pfc_xoff_prio1_count>0 {bins pfc_xoff_prio1_received ={1} ;bins no_pfc_xoff_prio1_received ={0} ;}
    cp_pfc_xoff_prio2 : coverpoint rx_pfc_xoff_prio2_count>0 {bins pfc_xoff_prio2_received ={1} ;bins no_pfc_xoff_prio2_received ={0} ;}
    cp_pfc_xoff_prio3 : coverpoint rx_pfc_xoff_prio3_count>0 {bins pfc_xoff_prio3_received ={1} ;bins no_pfc_xoff_prio3_received ={0} ;}
    cp_pfc_xoff_prio4 : coverpoint rx_pfc_xoff_prio4_count>0 {bins pfc_xoff_prio4_received ={1} ;bins no_pfc_xoff_prio4_received ={0} ;}
    cp_pfc_xoff_prio5 : coverpoint rx_pfc_xoff_prio5_count>0 {bins pfc_xoff_prio5_received ={1} ;bins no_pfc_xoff_prio5_received ={0} ;}
    cp_pfc_xoff_prio6 : coverpoint rx_pfc_xoff_prio6_count>0 {bins pfc_xoff_prio6_received ={1} ;bins no_pfc_xoff_prio6_received ={0} ;}
    cp_pfc_xoff_prio7 : coverpoint rx_pfc_xoff_prio7_count>0 {bins pfc_xoff_prio7_received ={1} ;bins no_pfc_xoff_prio7_received ={0} ;}
    cp_pfc_xon_prio0 : coverpoint rx_pfc_xon_prio0_count>0 {bins pfc_xon_prio0_received ={1} ;bins no_pfc_xon_prio0_received ={0} ;}
    cp_pfc_xon_prio1 : coverpoint rx_pfc_xon_prio1_count>0 {bins pfc_xon_prio1_received ={1} ;bins no_pfc_xon_prio1_received ={0} ;}
    cp_pfc_xon_prio2 : coverpoint rx_pfc_xon_prio2_count>0 {bins pfc_xon_prio2_received ={1} ;bins no_pfc_xon_prio2_received ={0} ;}
    cp_pfc_xon_prio3 : coverpoint rx_pfc_xon_prio3_count>0 {bins pfc_xon_prio3_received ={1} ;bins no_pfc_xon_prio3_received ={0} ;}
    cp_pfc_xon_prio4 : coverpoint rx_pfc_xon_prio4_count>0 {bins pfc_xon_prio4_received ={1} ;bins no_pfc_xon_prio4_received ={0} ;}
    cp_pfc_xon_prio5 : coverpoint rx_pfc_xon_prio5_count>0 {bins pfc_xon_prio5_received ={1} ;bins no_pfc_xon_prio5_received ={0} ;}
    cp_pfc_xon_prio6 : coverpoint rx_pfc_xon_prio6_count>0 {bins pfc_xon_prio6_received ={1} ;bins no_pfc_xon_prio6_received ={0} ;}
    cp_pfc_xon_prio7 : coverpoint rx_pfc_xon_prio7_count>0 {bins pfc_xon_prio7_received ={1} ;bins no_pfc_xon_prio7_received ={0} ;} 
  endgroup
  function new(string name = "eth_sbscr", uvm_component parent = null);
    super.new(name,parent);
    ethernet_cg1 = new();
    ethernet_cg2 = new();
    foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);
    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction   
  function void update_counters(eth_seq_item t);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      if(t.mac_addr[i] == mac_addr) begin
	case(i) 
	  0:begin
              rx_pause_xoff_cnt       = eth_top.ui_inf[0].rx_pause_xoff_count;
              rx_pause_xon_cnt        = eth_top.ui_inf[0].rx_pause_xon_count;
              rx_pfc_xoff_cnt         = eth_top.ui_inf[0].rx_pfc_xoff_count;
              rx_pfc_xon_cnt          = eth_top.ui_inf[0].rx_pfc_xon_count;
              rx_runt_good_fcs_cnt    = eth_top.ui_inf[0].rx_runt_count;
              rx_runt_bad_fcs_cnt     = eth_top.ui_inf[0].rx_fragment_count;
              rx_jabber_cnt           = eth_top.ui_inf[0].rx_jabber_count;
              rx_pfc_xon_prio0_count  = eth_top.ui_inf[0].rx_pfc_xon_prio0_count;
	      rx_pfc_xon_prio1_count  = eth_top.ui_inf[0].rx_pfc_xon_prio1_count;
	      rx_pfc_xon_prio2_count  = eth_top.ui_inf[0].rx_pfc_xon_prio2_count;
	      rx_pfc_xon_prio3_count  = eth_top.ui_inf[0].rx_pfc_xon_prio3_count;
	      rx_pfc_xon_prio4_count  = eth_top.ui_inf[0].rx_pfc_xon_prio4_count;
	      rx_pfc_xon_prio5_count  = eth_top.ui_inf[0].rx_pfc_xon_prio5_count;
	      rx_pfc_xon_prio6_count  = eth_top.ui_inf[0].rx_pfc_xon_prio6_count;
	      rx_pfc_xon_prio7_count  = eth_top.ui_inf[0].rx_pfc_xon_prio7_count;
	      rx_pfc_xoff_prio0_count = eth_top.ui_inf[0].rx_pfc_xoff_prio0_count;
	      rx_pfc_xoff_prio1_count = eth_top.ui_inf[0].rx_pfc_xoff_prio1_count;
	      rx_pfc_xoff_prio2_count = eth_top.ui_inf[0].rx_pfc_xoff_prio2_count;
	      rx_pfc_xoff_prio3_count = eth_top.ui_inf[0].rx_pfc_xoff_prio3_count;
	      rx_pfc_xoff_prio4_count = eth_top.ui_inf[0].rx_pfc_xoff_prio4_count;
	      rx_pfc_xoff_prio5_count = eth_top.ui_inf[0].rx_pfc_xoff_prio5_count;
	      rx_pfc_xoff_prio6_count = eth_top.ui_inf[0].rx_pfc_xoff_prio6_count;
	      rx_pfc_xoff_prio7_count = eth_top.ui_inf[0].rx_pfc_xoff_prio7_count;
            end
          1:begin
              rx_pause_xoff_cnt       = eth_top.ui_inf[1].rx_pause_xoff_count;
              rx_pause_xon_cnt        = eth_top.ui_inf[1].rx_pause_xon_count;
              rx_pfc_xoff_cnt         = eth_top.ui_inf[1].rx_pfc_xoff_count;
              rx_pfc_xon_cnt          = eth_top.ui_inf[1].rx_pfc_xon_count;
              rx_runt_good_fcs_cnt    = eth_top.ui_inf[1].rx_runt_count;
              rx_runt_bad_fcs_cnt     = eth_top.ui_inf[1].rx_fragment_count;
              rx_jabber_cnt           = eth_top.ui_inf[1].rx_jabber_count;
              rx_pfc_xon_prio0_count  = eth_top.ui_inf[1].rx_pfc_xon_prio0_count;
              rx_pfc_xon_prio1_count  = eth_top.ui_inf[1].rx_pfc_xon_prio1_count;
              rx_pfc_xon_prio2_count  = eth_top.ui_inf[1].rx_pfc_xon_prio2_count;
              rx_pfc_xon_prio3_count  = eth_top.ui_inf[1].rx_pfc_xon_prio3_count;
              rx_pfc_xon_prio4_count  = eth_top.ui_inf[1].rx_pfc_xon_prio4_count;
              rx_pfc_xon_prio5_count  = eth_top.ui_inf[1].rx_pfc_xon_prio5_count;
              rx_pfc_xon_prio6_count  = eth_top.ui_inf[1].rx_pfc_xon_prio6_count;
              rx_pfc_xon_prio7_count  = eth_top.ui_inf[1].rx_pfc_xon_prio7_count;
              rx_pfc_xoff_prio0_count = eth_top.ui_inf[1].rx_pfc_xoff_prio0_count;
              rx_pfc_xoff_prio1_count = eth_top.ui_inf[1].rx_pfc_xoff_prio1_count;
              rx_pfc_xoff_prio2_count = eth_top.ui_inf[1].rx_pfc_xoff_prio2_count;
              rx_pfc_xoff_prio3_count = eth_top.ui_inf[1].rx_pfc_xoff_prio3_count;
              rx_pfc_xoff_prio4_count = eth_top.ui_inf[1].rx_pfc_xoff_prio4_count;
              rx_pfc_xoff_prio5_count = eth_top.ui_inf[1].rx_pfc_xoff_prio5_count;
              rx_pfc_xoff_prio6_count = eth_top.ui_inf[1].rx_pfc_xoff_prio6_count;
              rx_pfc_xoff_prio7_count = eth_top.ui_inf[1].rx_pfc_xoff_prio7_count;
            end
        endcase
      end
    end
  endfunction 

  function void write_ap_3(eth_seq_item t);
  endfunction

  function void write_ap_4(eth_seq_item t);
    tr = t;
    mac_addr = t.agt_addr;
    update_counters(t);    
    ethernet_cg1.sample();
    ethernet_cg2.sample();
  endfunction

  function void write(eth_seq_item t);
    tr = t;
    mac_addr = t.agt_addr;
    update_counters(t);    
    ethernet_cg1.sample();
    ethernet_cg2.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("FUNC_COV",$sformatf("cg1 Coverage        = %0.2f%%",ethernet_cg1.get_inst_coverage()),UVM_NONE)
    `uvm_info("FUNC_COV",$sformatf("ethernet_cg2 Coverage = %0.2f%%",ethernet_cg2.get_inst_coverage()),UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("Overall Coverage    = %0.2f%%",$get_coverage()),UVM_NONE)
  endfunction
endclass



