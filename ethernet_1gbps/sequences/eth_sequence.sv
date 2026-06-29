class base_seq extends uvm_sequence #(eth_seq_item);
  `uvm_object_utils(base_seq)
  
  bit mode;
  bit [47:0] da;
  rand int c_ether_type;
  bit err_b;
  int err_offset;
  bit vlan_en;
  bit [15:0] TPID;
  bit payload_rand_en;
  bit pause_frame_en;
  bit [15:0] pause_opc;
  bit [15:0] pause_time; 
  bit corrupt_preamble_en;
  bit corrupt_fcs_en;
  static int trans_count;
  bit custom_da;
  bit [11:0] VID;
  bit invld_length_en;
  bit send_runt;
  bit len_payload_mismat_en; 
  bit corrupt_ipg_en;
  int pkt_no;
  int error_pkt_no;
  int exact_pkt;
  bit padding_en;
  bit[2:0] pcp;
  bit pfc_frame_en ; 
  bit pause_sel;
  bit pfc_sel;  
  bit pause_rsd_en;
  bit middle_coll_en;
  bit max_coll_en;
  int constant_rand_slot;
  int coll_byte;
  bit late_coll_en;
  bit burst_en;
  bit pfc_overlap_en;
  int temp_pcp; 
  bit [15:0] priority_en_vector;
  bit [15:0] pfc_pause_time[8];
  bit basic_pfc_en;
  bit pfc_rand_pri_en;
  bit force_pcp_en;
  bit [2:0]force_pcp;
  
  function new (string name = "base_seq");
    super.new(name);
  endfunction
endclass


class gmii_eth_normal_frame_seq extends base_seq;
  eth_seq_item req;
  `uvm_object_utils(gmii_eth_normal_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  
  function new (string name = "gmii_eth_normal_frame_seq");
    super.new(name);
  endfunction
  
  task body();
    `uvm_info(get_type_name(), "gmii_eth_normal_frame_seq: Inside Body", UVM_LOW)
    req = eth_seq_item::type_id::create("req");
    start_item(req);
    trans_count++;
    exact_pkt = find_no(trans_count);
    if(this.invld_length_en == 1)
      c_ether_type = $urandom_range(1501, 1536);
    if(this.padding_en == 1)
      req.padding_en = 1;
      // Complete frame fields from preamble to payload will be generated
      if(payload_rand_en == 1) 
        req.randomize() with {sa == p_sequencer.mac_addr;};   
      else
        req.randomize() with {sa == p_sequencer.mac_addr;       
                              ether_type == c_ether_type;};  
      req.mode = mode;
      req.middle_coll_en = middle_coll_en;
      req.max_coll_en = max_coll_en;
      req.constant_rand_slot = constant_rand_slot;
      req.late_coll_en = late_coll_en;
      req.burst_en = burst_en;
      if(late_coll_en) begin
        req.coll_byte = ($urandom_range(req.ether_type, 46)) + 22;
      end
      if(custom_da)
        req.da=da;   
      if(this.err_b == 1) begin
        req.err_b      = 1;
        req.err_offset = this.err_offset;
       `uvm_info("SEQ_ERR_PKT",$sformatf("Injecting error in packet no = %0d", exact_pkt),UVM_LOW)
      end    
      if(this.vlan_en == 1) begin
        req.vlan_en = this.vlan_en;
        req.TPID = this.TPID;
        req.DEI = 0;
        req.PCP = this.pcp;
        if(!pfc_sel) begin
          req.TPID=16'h8100;
          if(basic_pfc_en)
            req.PCP = $urandom_range(1,3);
          else if(pfc_rand_pri_en) begin
            if($urandom_range(0,2)<=1)
              req.PCP=temp_pcp;
            else
             req.PCP=$urandom_range(0,7);
          end
          else if(force_pcp_en)
            req.PCP=force_pcp; 
          else if(pfc_overlap_en)
             req.PCP=$urandom_range(0,7); 
          else 
           req.PCP=$urandom_range(0,7);
         end  
          req.VID = 0;
        end
      //--------------------pause_frame--------
      if(pause_sel) begin
  	    req.pause_frame_en = 1;
        req.pause_opc      = 16'h0001;
        req.ether_type     = 16'h8808;
        req.pause_time     = this.pause_time;
	      if($urandom_range(0,1))
	        req.da             = 48'h0180c2000001;
        if(this.pause_rsd_en) 
          req.pause_opc      = 16'h0002;
      end
     //--------------------------pfc_frame--------------
     if(pfc_sel) begin
        req.pfc_frame_en=1;
        req.pause_opc =16'h0101;
	      if($urandom_range(0,1))
	        req.da             = 48'h0180c2000001;
        req.vlan_en      = 0;
        req.ether_type =16'h8808;
        req.priority_en_vector=this.priority_en_vector;
        for(int i=0;i<8;i++) 
          req.pfc_pause_time[i]= this.pfc_pause_time[i];   
     end  
     //length and payload mismatch
     if(len_payload_mismat_en == 1) begin
       req.ether_type = $urandom_range(46,1500);
       `uvm_info("LEN_MISMATCH", $sformatf("Sending wrong Length in Transaction=%d",exact_pkt),UVM_LOW)
     end
     //CORRUPTED PREAMBLE
     if(this.corrupt_preamble_en == 1) begin
       req.preamble[pkt_no] = 8'hFF;
       `uvm_info("PREAMBLE CORRUPT", $sformatf("Sending Corrupted Preamble in Byte = %0d, Transaction no = %0d",pkt_no,exact_pkt),UVM_LOW)
     end
     //CORRUPT FCS
     if(this.corrupt_fcs_en == 1) begin
       req.corrupt_fcs_en = 1;
       `uvm_info("CORRUPT FCS TX",$sformatf("Sending bad fcs in Transaction = %0d",exact_pkt),UVM_LOW)
     end
     else
       req.corrupt_fcs_en = 0;
     //CORRUPT IPG
     if(this.corrupt_ipg_en == 1) begin        
       req.ipg_cnt = $urandom_range(1,11);
       `uvm_info("CORRUPT IPG",$sformatf("Sending Corrupted IPG Frame after Transaction no = %0d, IPG Count = %0d",
        exact_pkt,req.ipg_cnt),UVM_LOW)
     end
     else
       req.ipg_cnt = 12;   
     finish_item(req);
  endtask
  
  function int find_no(int a);
    if((a % 2) == 0)
      return (a/2);
    else
      return ((a/2)+1);
  endfunction
endclass
