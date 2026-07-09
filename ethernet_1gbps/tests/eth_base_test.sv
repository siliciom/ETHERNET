class eth_base_test extends uvm_test;
  `uvm_component_utils(eth_base_test);

  eth_env env_h;
  virtual_seq v_seq;
  int no_of_pkts = 1000;
  function new(string name = "eth_base_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if($value$plusargs("NO_OF_PKTS=%0d", no_of_pkts))
      `uvm_info(get_type_name(),$sformatf("NO_OF_PKTS from plusarg = %0d", no_of_pkts), UVM_LOW)
    else
      `uvm_info(get_type_name(), $sformatf("Using default NO_OF_PKTS = %0d", no_of_pkts),UVM_LOW)
    env_h = eth_env::type_id::create("env_h",this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task wait_until_complete();
    for(int i = 0; i< `NO_OF_AGENTS; i++) begin
      wait(env_h.agnt_mac[i].drv_h.frame_in_progress == 0 && env_h.agnt_mac[i].drv_h.backoff_k == 0);
      wait(env_h.agnt_mac[i].mon_h.frame_transmission == 0);
      if(env_h.agnt_mac[i].mon_h.rx_frame_q.size() != 0) 
	wait(env_h.agnt_mac[i].mon_h.rx_frame_q.size() == 0);
    end
  endtask
endclass

class gmii_eth_normal_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_normal_frame_test)
  function new (string name = "gmii_eth_normal_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.start(env_h.vseqr_h);  
    end
    wait_until_complete();
    #96;
    wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass

class gmii_eth_max_size_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_max_size_frame_test)
  function new (string name = "gmii_eth_max_size_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.ether_type = 1500;
      vseq.payload_rand_en = 0;
      vseq.start(env_h.vseqr_h);
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask  
endclass

class gmii_eth_min_size_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_min_size_frame_test)
  function new (string name = "gmii_eth_min_size_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.ether_type = 40;
      vseq.payload_rand_en = 0;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #96;
    wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass

class gmii_eth_error_detection_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_error_detection_test)
  error_cb err_cb;
  function new(string name = "gmii_eth_error_detection_test", uvm_component parent = null);
     super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     err_cb = error_cb::type_id::create("err_cb");
  endfunction
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv, error_cb)::add( env_h.agnt_mac[0].drv_h, err_cb);
    uvm_callbacks#(eth_drv, error_cb)::add( env_h.agnt_mac[1].drv_h, err_cb);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override( UVM_ERROR,"TX_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override( UVM_ERROR,"RX_ERR",UVM_WARNING);
    end
    phase.raise_objection(this);
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.mode = 1;
      vseq.payload_rand_en = 1;
      vseq.padding_en = 1;
      void'(std::randomize(err_cb.ctrl_error_en) with {err_cb.ctrl_error_en dist {0:=70, 1:=30};});
       vseq.start(env_h.vseqr_h);
    end
    wait_until_complete();
    #100;
    //wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass

class gmii_eth_vlan_tag_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_vlan_tag_frame_test)
  function new (string name = "gmii_eth_vlan_tag_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.vlan_en = 1;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_preamble_corruption_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_preamble_corruption_test)
    error_cb err_cb;
    function new (string name = "gmii_eth_preamble_corruption_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      err_cb = error_cb::type_id::create("err_cb");
  endfunction   
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
   uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[0].drv_h, err_cb);
 endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_PREAMBLE_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_PREAMBLE_ERR",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"TX_PREAMBLE_ASSERT",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"RX_PREAMBLE_ASSERT",UVM_WARNING);      
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");  
      vseq.mode = 1;
      vseq.payload_rand_en = 1;
      void'(std::randomize(err_cb.bad_preamble_en) with {err_cb.bad_preamble_en dist {0:=70, 1:=30};});
      vseq.padding_en =1;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_frame_with_ext_bit_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_frame_with_ext_bit_test)
  function new (string name = "gmii_eth_frame_with_ext_bit_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.payload_rand_en = 0;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_runt_good_fcs_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_runt_good_fcs_test)
  function new (string name = "gmii_eth_runt_good_fcs_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    // Demoting expected errors
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"MON_PADDING_ERROR",UVM_WARNING);
      uvm_root::get().set_report_severity_id_override( UVM_ERROR, "ASSERT_MIN_RX_FRAME", UVM_WARNING);
      uvm_root::get().set_report_severity_id_override( UVM_ERROR, "ASSERT FOR min_tx_frame", UVM_WARNING);      
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(vseq.runt_en) with {vseq.runt_en dist {0:=70, 1:=30};});
      if(vseq.runt_en) begin
	vseq.payload_rand_en = 0;
        vseq.ether_type = $urandom_range(0,45);
	vseq.padding_en = 0;
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_bad_fcs_test extends eth_base_test;
   error_cb err_cb;
  `uvm_component_utils(gmii_eth_bad_fcs_test)
  function new (string name = "gmii_eth_bad_fcs_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
        err_cb = error_cb::type_id::create("err_cb");
    endfunction    
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
  uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[0].drv_h, err_cb);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_CRC_DROP",UVM_WARNING);
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.mode = 1;     
      vseq.payload_rand_en = 1;
     void'(std::randomize(err_cb.bad_fcs_en) with {err_cb.bad_fcs_en dist {0:=70, 1:=30};});
     vseq.padding_en =1;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass


class gmii_eth_invalid_dest_addr_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_invalid_dest_addr_test)
  function new (string name = "gmii_eth_invalid_dest_addr_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
   foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_INVALID_DA",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_INVALID_DA",UVM_WARNING);
      env_h.scb_h.set_report_severity_id_override(UVM_ERROR,"SB_INVALID_DA",UVM_WARNING);
    end 
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(vseq.custom_da) with {vseq.custom_da dist {0:=70, 1:=30};});
      if(vseq.custom_da) begin
	vseq.da = 48'h88_88_88_88_88_88;
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_normal_frame_undefined_length_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_normal_frame_undefined_length_test)
  function new (string name = "gmii_eth_normal_frame_undefined_length_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_UNDEFINED_ETHERTYPE",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_UNDEFINED_ETHERTYPE",UVM_WARNING);
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.payload_rand_en = 0;
      void'(std::randomize(vseq.invld_length_en) with {vseq.invld_length_en dist {0:=70, 1:=30};});
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_collision_detect_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_collision_detect_test)
  function new (string name = "gmii_eth_collision_detect_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.coll_en = 1;  
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_ipg_violation_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_ipg_violation_test)
  function new (string name = "gmii_eth_ipg_violation_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_IPG_VIOLATION",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_IPG_VIOLATION",UVM_WARNING);
    end
    uvm_root::get().set_report_severity_id_override(UVM_ERROR,"ASSERT for ifg",UVM_WARNING);
    uvm_root::get().set_report_severity_id_override(UVM_ERROR,"ASSERT_RX_IFG",UVM_WARNING);    

    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
    vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(vseq.corrupt_ipg_en) with {vseq.corrupt_ipg_en dist {0:=70, 1:=30};});
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_len_payload_mismatch_test extends eth_base_test;
 error_cb err_cb;
  `uvm_component_utils(gmii_eth_len_payload_mismatch_test)
  function new (string name = "gmii_eth_len_payload_mismatch_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    err_cb = error_cb::type_id::create("err_cb");
  endfunction   
   function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv,error_cb)::add( env_h.agnt_mac[0].drv_h, err_cb);
  endfunction 
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"MON_LEN_MISMATCH",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_LEN_DATA_MISMATCH",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_LEN_DATA_MISMATCH",UVM_WARNING);
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.mode = 1;      
      vseq.payload_rand_en = 1;
      void'(std::randomize(err_cb.len_mismatch_en) with {err_cb.len_mismatch_en dist {0:=70, 1:=30};});
      vseq.padding_en =1;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_normal_payload_padding_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_normal_payload_padding_test)
  function new (string name = "gmii_eth_normal_payload_padding_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.ether_type = $urandom_range(0,45);
      vseq.payload_rand_en = 0;
      vseq.start(env_h.vseqr_h);
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask  
endclass


class gmii_eth_vlan_payload_padding_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_vlan_payload_padding_test)
  function new (string name = "gmii_eth_vlan_payload_padding_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.vlan_en = 1;
      vseq.payload_rand_en = 0;
      vseq.ether_type = $urandom_range(0,41);
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_collision_in_middle_bytes_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_collision_in_middle_bytes_test)
  function new (string name = "gmii_eth_collision_in_middle_bytes_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");    
      vseq.coll_en = 1;
      vseq.middle_coll_en = 1;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_broadcast_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_broadcast_frame_test)
  function new (string name = "gmii_eth_broadcast_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;   
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.broadcast_en = 1;
      vseq.custom_da = 1;
      vseq.da = 48'hFF_FF_FF_FF_FF_FF;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_jabber_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_jabber_frame_test)
  function new (string name = "gmii_eth_jabber_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_JABBER_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_JABBER_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_CRC_DROP",UVM_WARNING);
    end   
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(vseq.corrupt_fcs_en) with {vseq.corrupt_fcs_en dist {0:=70, 1:=30};});
      if(vseq.corrupt_fcs_en) begin
	vseq.ether_type = $urandom_range(1536, 2000);
	vseq.payload_rand_en = 0;
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pause_frame_basic_xon_xoff_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pause_frame_basic_xon_xoff_test)
  function new (string name = "gmii_eth_pause_frame_basic_xon_xoff_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);          
    vseq = virtual_seq::type_id::create("vseq");
    vseq.no_of_pkts = no_of_pkts;
    vseq.ether_type = 46;
    vseq.payload_rand_en = 0;
    vseq.pause_normal_traffic = 1;
    vseq.normal_xon_xoff_en = 1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,1000);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_simultaneous_pause_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_simultaneous_pause_frame_test )
  function new (string name = "gmii_eth_simultaneous_pause_frame_test ", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);          
    vseq = virtual_seq::type_id::create("vseq");
    vseq.no_of_pkts = no_of_pkts;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.pause_normal_traffic = 1;
    vseq.pause_simul_en = 1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,100);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pause_reserved_opcode_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pause_reserved_opcode_test)
  function new (string name = "gmii_eth_pause_reserved_opcode_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
   task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = no_of_pkts;
      vseq.pause_normal_traffic=1;
      vseq.pfc_with_vlan_traffic =0;
      vseq.pause_rsd_en=1;
      vseq.start(env_h.vseqr_h);
      phase.phase_done.set_drain_time(this,100);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pause_frame_with_upadated_pause_time extends eth_base_test;
  `uvm_component_utils(gmii_eth_pause_frame_with_upadated_pause_time )
  function new (string name = "gmii_eth_pause_frame_with_upadated_pause_time ", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.no_of_pkts = no_of_pkts;
    vseq.payload_rand_en = 0;
    vseq.ether_type=46;
    vseq.pause_normal_traffic=1;
    vseq.pfc_with_vlan_traffic =0;
    vseq.pause_update_time_en =1;
    vseq.start(env_h.vseqr_h); 
    phase.phase_done.set_drain_time(this,100);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_multicast_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_multicast_frame_test)
  function new (string name = "gmii_eth_multicast_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;   
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.multicast_en = 1;
      vseq.custom_da = 1;
      vseq.da = 48'h01_50_40_30_20_10;
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pause_frame_during_vlan_traffic_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pause_frame_during_vlan_traffic_test)
  function new (string name = "gmii_eth_pause_frame_during_vlan_traffic_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);          
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.ether_type = 46;
    vseq.payload_rand_en = 0;
    vseq.pause_normal_traffic = 1;
    vseq.vlan_en=1;
    vseq.TPID =16'h8100;
    vseq.vlan_pause_en=1;
    vseq.normal_xon_xoff_en = 1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,1000);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_max_collision_attempt_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_max_collision_attempt_test)
  function new (string name = "gmii_eth_max_collision_attempt_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");    
      vseq.mode = 0;
      vseq.payload_rand_en = 1;
      vseq.padding_en =1;
      void'(std::randomize(vseq.max_coll_en) with { vseq.max_coll_en dist {0 := 70, 1 := 30}; });
      if(vseq.max_coll_en) begin
	`uvm_info("Max Collision", "Setting Excessive Collision Occurence",UVM_LOW)
        vseq.coll_en = 1;  
        vseq.constant_rand_slot = 3; //Same randomized slot time to acheive the maximum collision
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_late_collision_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_late_collision_test)
  function new (string name = "gmii_eth_late_collision_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");    
      vseq.mode = 0;
      vseq.payload_rand_en = 1;
      vseq.padding_en =1;
      void'(std::randomize(vseq.late_coll_en) with { vseq.late_coll_en dist {0 := 70, 1 := 30}; });
      if(vseq.late_coll_en) begin
	`uvm_info("Late Collision", "Setting Late Collision Occurence",UVM_LOW);
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_long_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_long_frame_test)
  function new (string name = "gmii_eth_long_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    bit send_long_pkt;
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_LONG_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_LONG_PKT",UVM_WARNING);
    end   
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(send_long_pkt) with {send_long_pkt dist {0:=70, 1:=30};});
      if(send_long_pkt) begin
	`uvm_info("LONG FRAME", "Sending Long Frame",UVM_LOW)
	vseq.ether_type = $urandom_range(1536, 2000);
	vseq.payload_rand_en = 0;
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_frame_bursting_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_frame_bursting_test)
  function new (string name = "gmii_eth_frame_bursting_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.burst_en = 1;
      vseq.payload_rand_en = 0;
      vseq.ether_type = 46;
      vseq.start(env_h.vseqr_h);  
    end
    wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass

class gmii_eth_pfc_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pfc_frame_test)
  function new (string name = "gmii_eth_pfc_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.basic_pfc_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,5000);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pfc_with_random_priority_quanta_expiry_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pfc_with_random_priority_quanta_expiry_test)
  function new (string name = "gmii_eth_pfc_with_random_priority_quanta_expiry_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.pfc_rand_pri_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,2500);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pfc_simultaneous_operation_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pfc_simultaneous_operation_test)
  function new (string name = "gmii_eth_pfc_simultaneous_operation_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.pfc_simul_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,200);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pfc_independent_timer_overlap_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pfc_independent_timer_overlap_test)
  function new (string name = "gmii_eth_pfc_independent_timer_overlap_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.pfc_overlap_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    wait_until_complete();
    #5000;
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_xoff_xon_back_to_back_pfc_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_xoff_xon_back_to_back_pfc_test)
  function new (string name = "gmii_eth_xoff_xon_back_to_back_pfc_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.vlan_en=1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.back_to_back_xoff_xon_en= 1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.basic_pfc_en = 0;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,200);
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_pfc_multiple_priority_xoff_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_pfc_multiple_priority_xoff_test)
  function new (string name = "gmii_eth_pfc_multiple_priority_xoff_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction 
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.multi_priority_pfc_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 42;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    phase.phase_done.set_drain_time(this,1000);
    phase.drop_objection(this);
  endtask 
endclass

class gmii_eth_consec_multiple_same_pfc_xoff_imd_xon_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_consec_multiple_same_pfc_xoff_imd_xon_test)
  function new (string name = "gmii_eth_consec_multiple_same_pfc_xoff_imd_xon_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.pfc_stress_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    #100;
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_consec_multiple_diff_pfc_xoff_imd_xon_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_consec_multiple_diff_pfc_xoff_imd_xon_test)
  function new (string name = "gmii_eth_consec_multiple_diff_pfc_xoff_imd_xon_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    vseq.mode = 1;
    vseq.pfc_with_vlan_traffic =1;
    vseq.multiple_pfc_stress_en = 1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
    wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

class gmii_eth_jumbo_frame_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_jumbo_frame_test)
  function new (string name = "gmii_eth_jumbo_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.mode            = 1;
      vseq.payload_rand_en = 0;
      vseq.padding_en      = 1;
      vseq.ether_type = $urandom_range(1537,16000);
      vseq.start(env_h.vseqr_h);
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask
endclass

class gmii_eth_mac2_mac3_addr_cov_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_mac2_mac3_addr_cov_test)
  virtual_seq vseq;
  function new(string name = "gmii_eth_mac2_mac3_addr_cov_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat(this.no_of_pkts/2) begin
      // MAC2 -> MAC3
      vseq = virtual_seq::type_id::create("mac2_mac3_vseq");
      vseq.mac23_en     = 1;
      vseq.swap_src_dst = 0;
      vseq.custom_da    = 1;
      vseq.da           = 48'h005343332313; // MAC3
      vseq.payload_rand_en = 1;
      vseq.start(env_h.vseqr_h);

      // MAC3 -> MAC2
      vseq = virtual_seq::type_id::create("mac3_mac2_vseq");
      vseq.mac23_en    = 1;
      vseq.swap_src_dst = 1;
      vseq.custom_da   = 1;
      vseq.da          = 48'h005242322212; // MAC2
      vseq.payload_rand_en = 1;
      vseq.start(env_h.vseqr_h);
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask
endclass

class gmii_eth_runt_bad_fcs_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_runt_bad_fcs_test)
  function new (string name = "gmii_eth_runt_bad_fcs_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_FRAGMENT_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_FRAGMENT_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"MON_PADDING_ERROR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_FRAGMENT_CRC",UVM_WARNING);
      uvm_root::get().set_report_severity_id_override( UVM_ERROR, "ASSERT_MIN_RX_FRAME", UVM_WARNING);
      uvm_root::get().set_report_severity_id_override( UVM_ERROR, "ASSERT FOR min_tx_frame", UVM_WARNING);      
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.mode = 1;
      vseq.payload_rand_en = 1;
      vseq.runt_en = 1;
      vseq.corrupt_fcs_en = 0;
      vseq.padding_en =1;
      void'(std::randomize(vseq.runt_en) with {vseq.runt_en dist {0:=70, 1:=30};});
      if(vseq.runt_en) begin
	vseq.payload_rand_en = 0;
	vseq.corrupt_fcs_en = 1;
	vseq.padding_en = 0;
      end
      vseq.start(env_h.vseqr_h);    
    end
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask    
endclass
