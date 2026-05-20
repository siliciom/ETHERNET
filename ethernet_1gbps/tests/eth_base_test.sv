class eth_base_test extends uvm_test;
  `uvm_component_utils(eth_base_test)
  
  eth_env env_h;
  virtual_seq v_seq;
  
  function new(string name = "eth_base_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_h = eth_env::type_id::create("env_h",this);
  endfunction
  
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
  
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    v_seq = virtual_seq::type_id::create("v_seq");  
    v_seq.start(env_h.vseqr_h);    
    `uvm_info(get_type_name(), "End of Test", UVM_LOW)       
    phase.drop_objection(this);
  endtask  
  
  
endclass
