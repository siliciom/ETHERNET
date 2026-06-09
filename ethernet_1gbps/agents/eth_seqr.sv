class eth_seqr extends uvm_sequencer#(eth_seq_item);
  `uvm_component_utils(eth_seqr);
  
  bit [47:0] mac_addr;
  
  function new(string name = "eth_seqr", uvm_component parent = null);
    super.new(name,parent);
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction    
endclass
