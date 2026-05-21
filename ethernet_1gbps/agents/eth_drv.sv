class eth_drv extends uvm_driver#(eth_seq_item);
  `uvm_component_utils(eth_drv);
  eth_seq_item tr;
  virtual eth_gmii_interface v_intf;
 
  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name,parent);
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    
    if(!uvm_config_db#(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"ETH GMII INTERFACE CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"ETH GMII INTERFACE CONNECTION_PASSED",UVM_LOW)    
  endfunction    
  
  task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(),"Entered the run phase of driver",UVM_LOW)    
    forever begin
    seq_item_port.get_next_item(tr);
    v_intf.TXD <= tr.data;
    
//     v_intf.TXD    <= tr.TXD;
//     v_intf.TX_ER  <= tr.TX_ER;
//     v_intf.TX_EN  <= tr.TX_EN;
//     v_intf.RXD    <= tr.RXD;
//     v_intf.RX_DV  <= tr.RX_DV;
//     v_inf.RX_ER   <= tr.RX_ER;
    
    @(posedge v_intf.TX_CLK); 
     seq_item_port.item_done(); 
    end
   
  endtask

endclass
