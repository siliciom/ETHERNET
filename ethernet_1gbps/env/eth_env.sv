class eth_env extends uvm_env;
  `uvm_component_utils(eth_env);
  
  eth_agnt agnt_mac[];
 
  eth_scb scb_h;
  eth_sbscr sbscr_h;
  
  eth_virtual_seqr vseqr_h;
  
  eth_seq_item seq_item_h;
  
  function new(string name = "eth_env", uvm_component parent = null);
    super.new(name,parent);
    agnt_mac = new[`NO_OF_AGENTS];
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    foreach (agnt_mac[i])
      agnt_mac[i] = eth_agnt::type_id::create($sformatf("agnt_mac[%0d]", i), this); 
    
      scb_h = eth_scb::type_id::create("scb_h",this);
      sbscr_h = eth_sbscr::type_id::create("sbscr_h",this);
    
      seq_item_h = eth_seq_item::type_id::create("seq_item_h");
      vseqr_h = eth_virtual_seqr::type_id::create("vseqr_h",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    foreach(agnt_mac[i]) begin
      // Scoreboard Connection
      agnt_mac[i].mon_h.tx_ap.connect(scb_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(scb_h.ai_2[i]);    
      
      // Subscriber Connection
      agnt_mac[i].mon_h.tx_ap.connect(sbscr_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(sbscr_h.ai_2[i]);       
    end
      
    
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      vseqr_h.mac_seqr_h[i] = agnt_mac[i].seqr_h; // Virtual Sequencer Connection
      agnt_mac[i].seqr_h.mac_addr = seq_item_h.mac_addr[i];      
      agnt_mac[i].drv_h.mac_addr = seq_item_h.mac_addr[i];
      agnt_mac[i].mon_h.mac_addr = seq_item_h.mac_addr[i];
      foreach(seq_item_h.multi_mac_addr[i][j])
	agnt_mac[i].mon_h.multi_mac_addr[j] = 1;
      statistics::pause_flag[seq_item_h.mac_addr[i]]   = 0;
      statistics::pause_value[seq_item_h.mac_addr[i]]  = 0;
      statistics::pause_update[seq_item_h.mac_addr[i]] = 0;
 
      for(int j=0;j<8;j++) begin
        statistics::pfc_flag [seq_item_h.mac_addr[i]][j] = 0;
        statistics::pfc_value[seq_item_h.mac_addr[i]][j] = 0;
        statistics::pfc_update[seq_item_h.mac_addr[i]][j] = 0;
      end
    end

  endfunction  
  
endclass
