class eth_virtual_seqr extends uvm_sequencer #(eth_seq_item);
  `uvm_component_utils(eth_virtual_seqr)

  eth_seqr mac_seqr_h[];

  function new(string name = "eth_virtual_seqr", uvm_component parent = null);
    super.new(name, parent);
    
    mac_seqr_h = new[`NO_OF_AGENTS];
    
  endfunction
  
endclass
