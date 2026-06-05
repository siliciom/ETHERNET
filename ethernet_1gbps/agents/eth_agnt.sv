class eth_agnt extends uvm_agent;
  `uvm_component_utils(eth_agnt);
  
  eth_seqr seqr_h;
  eth_drv drv_h;
  eth_mon mon_h;
  

  
  function new(string name = "eth_agnt", uvm_component parent = null);
    super.new(name,parent);
  endfunction  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqr_h = eth_seqr::type_id::create("seqr_h",this);
    drv_h = eth_drv::type_id::create("drv_h",this);
    mon_h = eth_mon::type_id::create("mon_h",this);    
  endfunction  
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv_h.seq_item_port.connect(seqr_h.seq_item_export);
  endfunction  
  
endclass
