class eth_base_test extends uvm_test;
  `uvm_component_utils(eth_base_test);
  
  eth_env env_h;
  virtual_seq v_seq;
  int no_of_pkts = 100;

  
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
    #100;
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
      vseq.start(env_h.vseqr_h);
    end
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
      vseq.start(env_h.vseqr_h);    
    end
    #100;
    phase.drop_objection(this);

  endtask  

endclass


class gmii_eth_error_detection_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_error_detection_test)
  
  function new (string name = "gmii_eth_error_detection_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    
  endfunction
  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    // Demoting expected errors
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_ERR",UVM_WARNING);
    end 
    
    phase.raise_objection(this); 
    vseq = virtual_seq::type_id::create("vseq");
    
    repeat(this.no_of_pkts) begin
      void'(std::randomize(vseq.err_b) with {vseq.err_b dist {0:=70, 1:=30};});
      if(vseq.err_b) vseq.err_offset = 50;  
      vseq.start(env_h.vseqr_h); 
    end
    #100;
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
    #100;
    phase.drop_objection(this);
  endtask    
  
endclass



class gmii_eth_preamble_corruption_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_preamble_corruption_test)
  
  function new (string name = "gmii_eth_preamble_corruption_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    // Demoting expected errors
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_PREAMBLE_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_PREAMBLE_ERR",UVM_WARNING);
    end
    phase.raise_objection(this);  
      
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");  
      void'(std::randomize(vseq.corrupt_preamble_en) with {vseq.corrupt_preamble_en dist {0:=70, 1:=30};});
      if(vseq.corrupt_preamble_en) vseq.set_corpt_pkt = $urandom_range(0,6); // corrupting any one byte of preamble
      vseq.start(env_h.vseqr_h);    
    end
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
    #100;
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
    end
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.corrupt_fcs_en = 0;
      void'(std::randomize(vseq.runt_en) with {vseq.runt_en dist {0:=70, 1:=30};});
      if(vseq.runt_en) begin
	vseq.payload_rand_en = 0;
        vseq.ether_type = $urandom_range(0,45);
	vseq.corrupt_fcs_en = 1;
	vseq.padding_en = 0;
      end
      vseq.start(env_h.vseqr_h);    
    end
    #100;
    phase.drop_objection(this);
  endtask    
endclass


class gmii_eth_bad_fcs_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_bad_fcs_test)
  
  function new (string name = "gmii_eth_bad_fcs_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
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
      void'(std::randomize(vseq.corrupt_fcs_en) with {vseq.corrupt_fcs_en dist {0:=70, 1:=30};});
      vseq.start(env_h.vseqr_h);    
    end
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
    #100;
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
    phase.raise_objection(this);  
    repeat(this.no_of_pkts) begin
    vseq = virtual_seq::type_id::create("vseq");
      void'(std::randomize(vseq.corrupt_ipg_en) with {vseq.corrupt_ipg_en dist {0:=70, 1:=30};});
      vseq.start(env_h.vseqr_h);    
    end
    #100;
    phase.drop_objection(this);
  endtask    
  
endclass


class gmii_eth_len_payload_mismat_test extends eth_base_test;
  `uvm_component_utils(gmii_eth_len_payload_mismat_test)
  
  function new (string name = "gmii_eth_len_payload_mismat_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
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
      void'(std::randomize(vseq.len_payload_mismat_en) with {vseq.len_payload_mismat_en dist {0:=70, 1:=30};});
      vseq.start(env_h.vseqr_h);    
    end
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
      vseq.start(env_h.vseqr_h);
    end
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
    #100;
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
    vseq.pfc_with_vlan_traffic =1;
    vseq.no_of_pkts = no_of_pkts;
    vseq.basic_pfc_en = 1;
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.vlan_en=1;
    vseq.start(env_h.vseqr_h);
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
    #100;
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
    #100;
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
    #100;
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
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_JABBER_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_JABBER_PKT",UVM_WARNING);
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
    #100;
    phase.drop_objection(this);
  endtask  

endclass
