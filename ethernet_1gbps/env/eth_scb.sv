`uvm_analysis_imp_decl(_ap_1)
`uvm_analysis_imp_decl(_ap_2)

class eth_scb extends uvm_scoreboard;
  `uvm_component_utils(eth_scb);
  
  uvm_analysis_imp_ap_1#(eth_seq_item, eth_scb) ai_1[`NO_OF_AGENTS];    //uvm_analysis_imp_m
  uvm_analysis_imp_ap_2#(eth_seq_item, eth_scb) ai_2[`NO_OF_AGENTS];  
  
  eth_seq_item tx_tr;
  eth_seq_item rx_tr;
  
  eth_seq_item tx_aa[int][int];
  eth_seq_item rx_aa[int][int];
  
  function new(string name = "eth_scb", uvm_component parent = null);
    super.new(name,parent);
   
    foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);
         
    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);
    
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction    
  
 
  //expected data received from monitor
  function void write_ap_1(eth_seq_item tx_tr);
    `uvm_info(get_type_name(), $sformatf("Expected TXD = %0h", tx_tr.data), UVM_LOW)       
  endfunction
  
  //actual data received from monitor
  function void write_ap_2(eth_seq_item rx_tr);
    `uvm_info(get_type_name(), $sformatf("Actual RXD = %0h", rx_tr.data), UVM_LOW)       
  endfunction
  
  
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info(get_type_name(), "Entered Check Phase", UVM_LOW)       
  endfunction
  
 
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "Entered Report Phase", UVM_LOW)       
  endfunction

endclass
