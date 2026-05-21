class eth_mon extends uvm_monitor;
  `uvm_component_utils(eth_mon);
  uvm_analysis_port #(eth_seq_item) tx_ap;
  uvm_analysis_port #(eth_seq_item) rx_ap;  
  
  virtual eth_gmii_interface v_intf;
  eth_seq_item tr_tx, tr_rx;
  
  function new(string name = "eth_mon", uvm_component parent = null);
    super.new(name,parent);
    tx_ap = new("tx_ap", this); 
    rx_ap = new("rx_ap", this);        
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    
    tr_tx = eth_seq_item::type_id::create("tr_tx");
    tr_rx = eth_seq_item::type_id::create("tr_rx");
    
    if(!uvm_config_db#(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"ETH GMII INTERFACE CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"ETH GMII INTERFACE CONNECTION_PASSED",UVM_LOW)    
        
  endfunction  
  
  task run_phase(uvm_phase phase);    
    `uvm_info(get_type_name(),"Entered the run phase of monitor",UVM_LOW)    
    forever begin
      @(posedge v_intf.TX_CLK);
      fork
        tx_mon();
        rx_mon();
      join_none
    end    
  endtask
    
  task tx_mon();    
     tr_tx.data   = v_intf.TXD;
     tx_ap.write(tr_tx);
    
    `uvm_info("TX MONITOR", $sformatf("TXD = %0h", tr_tx.data), UVM_LOW)       
  endtask
    
  task rx_mon();
    tr_rx.data = v_intf.RXD;
    rx_ap.write(tr_rx);
    statistics::v_uif[0].tx_good_pkt_count = 2;
    `uvm_info("RX MONITOR", $sformatf("RXD = %0h", tr_rx.data), UVM_LOW) 
    `uvm_info("RX MONITOR", $sformatf("counter vaue = %0d", statistics::v_uif[0].tx_good_pkt_count), UVM_LOW) 
  endtask
               
endclass
