`uvm_analysis_imp_decl(_ap_3)
`uvm_analysis_imp_decl(_ap_4)

class eth_sbscr extends uvm_subscriber#(eth_seq_item);
  `uvm_component_utils(eth_sbscr);
 
  uvm_analysis_imp_ap_3#(eth_seq_item, eth_sbscr) ai_1[`NO_OF_AGENTS]; 
  uvm_analysis_imp_ap_4#(eth_seq_item, eth_sbscr) ai_2[`NO_OF_AGENTS]; 
    
  function new(string name = "eth_sbscr", uvm_component parent = null);
    super.new(name,parent);
     foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);
         
    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);
    
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction    
  
  function void write_ap_3(eth_seq_item t);
  endfunction

  function void write_ap_4(eth_seq_item t);
  endfunction

  function void write(eth_seq_item t);
  endfunction

 
endclass
