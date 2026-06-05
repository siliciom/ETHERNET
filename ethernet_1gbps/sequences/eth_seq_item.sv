class eth_seq_item extends uvm_sequence_item;

  rand bit [7:0] preamble[7];
  rand bit [7:0] sfd;
  rand bit [47:0] da;
  rand bit [47:0] sa;
  rand bit [15:0] ether_type;
  rand bit [7:0] payload[];
  bit [31:0] crc;
  bit [47:0] mac_addr[`NO_OF_AGENTS];
  bit multi_mac_addr[`NO_OF_AGENTS][bit [47:0]];
  bit mode;
  bit carr_ext_en;
  bit [47:0] agt_addr;
  int tx_count;
  
  //VLAN Fields
  bit vlan_en;
  bit [2:0] PCP;
  bit DEI;
  bit [11:0] VID;
  bit [15:0] TPID;
  bit [47:0] agent_mc_mac[`NO_OF_AGENTS];
  
  
  //Pause Fields
  bit pause_frame_en;
  bit [15:0] pause_opc;
  bit [15:0] pause_time;
  
  //Error Fields
  bit err_b;  
  int unsigned err_offset; // At which byte index should tx_er go high  
  bit corrupt_fcs_en;
  int ipg_cnt;
  
  bit preamble_err;
  int rx_count; 
  bit padding_en;
  
  //pfc
  bit pfc_frame_en;
  bit [15:0] priority_en_vector; 
  bit [15:0] pfc_pause_time[8];  
  bit max_coll_en;
  int constant_rand_slot;
  
  `uvm_object_utils_begin(eth_seq_item)
  `uvm_field_int(da, UVM_ALL_ON)   // <-- DA
  `uvm_field_int(sa, UVM_ALL_ON)   // <-- SA
  `uvm_field_sarray_int(payload, UVM_ALL_ON) 
  `uvm_field_int(crc,UVM_ALL_ON)
  `uvm_field_int(ether_type,UVM_ALL_ON)	
  `uvm_object_utils_end
  
  function new(string name = "transaction");
    super.new(name);
    // Initializing unique mac addresses for each mac
    for (int i = 0; i < `NO_OF_AGENTS; i++)
      mac_addr[i] = {8'h00,8'(8'h50 + i),8'(8'h40 + i),8'(8'h30 + i),8'(8'h20 + i),8'(8'h10 + i)};
    mac_multicast(multi_mac_addr);
    
  endfunction
  
  // CRC Generator
  function bit [31:0] crc_32 (bit [31:0] crc, bit[7:0] data);
    crc = crc^data;
  
    for (int i=0; i<8; i++) begin
      if(crc[0])
        crc = (crc>>1) ^ 32'hEDB88320;
      else
        crc = crc>>1;
    end

    return crc; 
  endfunction  
  
   
  constraint preamble_value {foreach(preamble[i]) preamble[i] == 8'h55;}
  constraint sfd_value {sfd == 8'hd5;}
  
  constraint ether_type_value {soft ether_type inside {[46:1500]};}
  constraint payload_size {payload.size() == ether_type;}
  
  constraint addr{ da inside {mac_addr};};
  constraint sa_da_not_match{ da != sa ;}

endclass


