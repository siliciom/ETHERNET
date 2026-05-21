class eth_env extends uvm_env;
  `uvm_component_utils(eth_env);
  
  eth_agnt agnt_mac[];
 
  eth_scb scb_h;
  eth_sbscr sbscr_h;
  
  eth_virtual_seqr vseqr_h;
  
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
      vseqr_h = eth_virtual_seqr::type_id::create("eth_virtual_seqr",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    foreach(agnt_mac[i]) begin
      // Scoreboard connection
      agnt_mac[i].mon_h.tx_ap.connect(scb_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(scb_h.ai_2[i]);    
      
      // Subscriber connection
      agnt_mac[i].mon_h.tx_ap.connect(sbscr_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(sbscr_h.ai_2[i]);       
    end   
    
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      // Virtual Sequencer connection
      vseqr_h.mac_seqr_h[i] = agnt_mac[i].seqr_h;
    end    
  endfunction  
  
endclass
