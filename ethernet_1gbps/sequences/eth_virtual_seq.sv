class base_virtual_seq extends uvm_sequence;
  `uvm_object_utils(base_virtual_seq)
  int ether_type;
  rand bit err_b;
  int err_offset;
  bit [47:0] da;
  bit vlan_en;
  bit [15:0] TPID;
  bit payload_rand_en = 1;
  rand bit corrupt_preamble_en;
  bit multicast_en;
  bit broadcast_en;
  bit pause_frame_en;
  bit [15:0] pause_opc;
  bit [15:0] pause_time;  
  bit mode;
  rand bit corrupt_fcs_en;
  rand bit custom_da;
  bit [11:0] VID;
  rand bit invld_length_en;
  rand bit runt_en;
  bit coll_en;
  rand bit len_payload_mismat_en;   
  rand bit corrupt_ipg_en;
  int set_corpt_pkt;
  int error_pkt_no;
  bit padding_en = 1;
  bit pfc_frame_en;   
  bit pfc_with_vlan_traffic;
  bit pause_normal_traffic ;
  int no_of_pkts;
  int count;
  int pause_gap_cnt;
  bit pause_simul_en;
  bit simul_pause_en2;
  bit simul_pause_time2;
  bit send_immediate_xon;
  bit normal_xon_xoff_en; 
  bit pause_rsd_en;
  bit pause_update_time_en;
  bit middle_coll_en;
  bit vlan_pause_en;
  bit max_coll_en;
  int constant_rand_slot;
  bit late_coll_en;
  bit burst_en;
  bit basic_pfc_en;
  bit pfc_overlap_en;
  bit pfc_simul_en;
  bit simul_pfc_en2;
  bit pfc_rand_pri_en;
  int paused_pcp_q[$];
  int paused_pcp_q2[$];
  int temp;
  int paused_pcp_q1[$];
  bit back_to_back_xoff_xon_en;
  bit waiting_for_xon;
  bit [2:0] paused_prio;
  bit seq2_pcp_en;
  bit vlan_phase;
  bit [2:0]pcp_temp;
  bit pkt_gap_cnt;
  bit pfc_stress_en;
  bit pcp_rand_en;  
  bit [2:0] t_pcp;
  int t_cnt;  
  bit multiple_pfc_stress_en;
  bit multi_priority_pfc_en;
  bit swap_src_dst;
  bit mac23_en;
  bit runt_bad_en;

  class randc_pcp;
    randc bit [2:0] rand_pcp;
  endclass  

  randc_pcp pcp_gen;

  function new (string name = "base_virtual_seq");
    super.new(name);
    pcp_gen = new();
  endfunction  
endclass

class virtual_seq extends base_virtual_seq;
  `uvm_object_utils(virtual_seq)
  `uvm_declare_p_sequencer(eth_virtual_seqr)
  gmii_eth_normal_frame_seq seq1, seq2;  
  function new (string name = "virtual_seq");
    super.new(name);
  endfunction  

  task body();
    `ifdef HALF_DUPLEX
       this.mode = 0;
    `else
       this.mode = 1;
    `endif
    if(!pause_normal_traffic && ! pfc_with_vlan_traffic) begin // This will work in default mode
      seq1 = gmii_eth_normal_frame_seq::type_id::create("seq1");
      seq2 = gmii_eth_normal_frame_seq::type_id::create("seq2");
      // Configure sequences config variables received from test
      apply_config(seq1);
      apply_config(seq2);
      if(mac23_en) begin
        if(!swap_src_dst) begin
          seq1.start(p_sequencer.mac_seqr_h[2]); // MAC2
        end
        else begin
          seq1.start(p_sequencer.mac_seqr_h[3]); // MAC3
        end
      end
      else begin
        if((this.mode == 0 && !coll_en) || multicast_en || broadcast_en) begin //Start only one sequence for half-duplex without collison,multicast and broadcast testcases
          seq1.start(p_sequencer.mac_seqr_h[0]);
        end
        // Start two sequences in parallel
        else begin
          if(this.middle_coll_en == 1) begin
            fork
              seq1.start(p_sequencer.mac_seqr_h[0]);
              #160 seq2.start(p_sequencer.mac_seqr_h[1]);
            join        
          end 
          else begin    
            fork
              seq1.start(p_sequencer.mac_seqr_h[0]);
              seq2.start(p_sequencer.mac_seqr_h[1]);
            join
          end
        end
      end
    end
    else begin
      if(this.mode==1) begin
        //------------------pause, normal traffic--------------
        if(pause_normal_traffic) begin
          fork
            begin
              repeat(this.no_of_pkts) begin
                seq1 = gmii_eth_normal_frame_seq::type_id::create("seq1");
                apply_config(seq1);
                if(pause_gap_cnt >0)
                  pause_gap_cnt--;
                if(send_immediate_xon) begin
                  seq1.pause_sel=1;
                  seq1.pause_time=0; //Xon
                  send_immediate_xon=0;
                end 
                //Normal_pause +(Xon & Xoff)
                else if(normal_xon_xoff_en && pause_gap_cnt==0 && $urandom_range(1,100)<10) begin
                  seq1.pause_sel = 1;
                  if($urandom_range(1,100)<=3)
                    seq1.pause_time=0; //xon
                  else begin
                    seq1.pause_time=$urandom_range(1,10); //xoff
                    if($urandom_range(1,100)<=70)
                      send_immediate_xon=1;
                  end   
                  pause_gap_cnt = $urandom_range(5,6);
                end 
                //reserved_opcode
                else if(pause_rsd_en && $urandom_range(0,100)<5) begin
                  seq1.pause_sel=1;
                  seq1.pause_rsd_en=pause_rsd_en;
                  seq1.pause_time=$urandom_range(1,10);
                end
                //pause_update_time
                else if(this.pause_update_time_en  && ($urandom_range(1,100)<20) ) begin
                  seq1.pause_sel =1;
                  seq1.pause_time=$urandom_range(1,10);
                end
                //simultaneous_pause_frames
                else if(this.pause_simul_en && $urandom_range(1,50)<5) begin
                  seq1.pause_sel  = 1;
                  seq1.pause_time = $urandom_range(1,10);
                  simul_pause_en2   = 1;
                  //simul_pause_time2 = $urandom_range(1,10);
                end
                //pause_with_vlan_frames
                else if(this.vlan_pause_en && $urandom_range(1,100)<7) begin
                  seq1.pause_sel=1;
                  seq1.pause_time=$urandom_range(1,10);
                end          
                else     
                  seq1.pause_sel=0;
                seq1.start(p_sequencer.mac_seqr_h[0]);
              end
            end
            begin
              repeat(this.no_of_pkts) begin
                seq2 = gmii_eth_normal_frame_seq::type_id::create("seq2");
                apply_config(seq2);
                if(simul_pause_en2) begin
                  seq2.pause_sel  = 1;
                  seq2.pause_time = $urandom_range(1,10);//simul_pause_time2;
                  simul_pause_en2 = 0;
                end
                else
                  seq2.pause_sel = 0;
                seq2.start(p_sequencer.mac_seqr_h[1]);
              end
            end
          join
        end 
        //---------------- VLAN TRAFFIC+pfc ----------------   
        if(pfc_with_vlan_traffic) begin
          fork
            begin
              repeat(this.no_of_pkts) begin
                seq1 = gmii_eth_normal_frame_seq::type_id::create($sformatf("vlan_seq_%0d",$time));
                apply_config(seq1);
                if(pfc_stress_en && !pcp_rand_en)
                  void'(std::randomize(seq1.pfc_sel) with {seq1.pfc_sel dist {0:=90, 1:=10};});
                if(pkt_gap_cnt >0)
                  pkt_gap_cnt--;
                //Basic_pfc  
                if(basic_pfc_en && $urandom_range(1,50)<10) begin
                  seq1.pfc_sel=1;    
                  seq1.temp_pcp=3;//$urandom_range(1,4);
                  seq1.priority_en_vector[seq1.temp_pcp] = 1;// priority[3] 
                  for(int i=0;i<8;i++)
                    seq1.pfc_pause_time[i]=$urandom_range(1,5);  
                end 
	        //multiple_priority_vector_enable	
                else if(multi_priority_pfc_en && (count != 0) && ((count+1)%20==0)) begin
                  int pri[$];
                  seq1.pfc_sel = 1;
                  foreach(seq1.pfc_pause_time[i])
                    seq1.pfc_pause_time[i] = $urandom_range(6,9);         // Give quanta to all priorities
                  seq1.priority_en_vector = '0;                           // Clear enable vector
                  for(int i=0;i<8;i++)                                    // Create priority list
                    pri.push_back(i);
                  pri.shuffle();                                          // Shuffle priorities
                  for(int i=0;i<4;i++)                                    // Enable any four priorities
                      seq1.priority_en_vector[pri[i]] = 1;
                  `uvm_info("MULTI_PFC", $sformatf("Packet=%0d Vector=%b Pause=%p", count+1, seq1.priority_en_vector, seq1.pfc_pause_time), UVM_LOW)
                end	
                //random_priority
                else if(pfc_rand_pri_en && $urandom_range(1,100)<=10) begin
                  seq1.pfc_sel=1;
		  assert(pcp_gen.randomize());
                  pcp_temp=pcp_gen.rand_pcp;
                  seq1.temp_pcp=pcp_temp;
                  seq2_pcp_en=1; 
                  seq1.priority_en_vector[seq1.temp_pcp]=1;
                  for(int i=0;i<8;i++) 
                    seq1.pfc_pause_time[i]=$urandom_range(1,10);
                end  
                //Simulataneous_pfc
                else if(pfc_simul_en && $urandom_range(1,50) <=10) begin
                  seq1.pfc_sel=1;
		  assert(pcp_gen.randomize());
                  seq1.temp_pcp=pcp_gen.rand_pcp;
                  paused_pcp_q.push_back(seq1.temp_pcp);
                  seq1.priority_en_vector[seq1.temp_pcp]=1;
                  for(int i=0;i<=7;i++) begin
                    seq1.pfc_pause_time[seq1.temp_pcp]=$urandom_range(5,10);
	          end
                  `uvm_info("seqqq_mac0",$sformatf("pcp=%0d, pfc_pause_time=%0d",seq1.temp_pcp,seq1.pfc_pause_time[seq1.temp_pcp]),UVM_LOW)
                  simul_pfc_en2=1;
                  if($urandom_range(1,50)<=30) begin
	            assert(pcp_gen.randomize());
                    temp=pcp_gen.rand_pcp;
                    if(temp inside {paused_pcp_q})
                      seq1.pfc_pause_time[temp]=0;
                  end 
                end  
                //Back_to_back_xoff_xon
                else if(back_to_back_xoff_xon_en &&(waiting_for_xon || $urandom_range(1,100)<10) && pkt_gap_cnt==0) begin
                  seq1.pfc_sel = 1;
                  if(!waiting_for_xon) begin
		    assert(pcp_gen.randomize());
                    paused_prio = pcp_gen.rand_pcp;
                    seq1.temp_pcp = paused_prio;
                    seq1.priority_en_vector[paused_prio] = 1;
                    for(int i=0;i<8;i++)
                      seq1.pfc_pause_time[i] = $urandom_range(5,10);
                    waiting_for_xon = 1; 
                    `uvm_info("VIRTUAL_SEQ",$sformatf(" XOFF sent for prio=%0d,priority_en[%0d]=%0d,pfc_pause_time[%0d]= %0d", paused_prio,
                             seq1.temp_pcp,seq1.priority_en_vector[paused_prio], seq1.temp_pcp,seq1.pfc_pause_time[paused_prio]),UVM_LOW)
                  end 
                  else begin
                    seq1.temp_pcp = paused_prio;
                    seq1.priority_en_vector[paused_prio] = 1;
                    seq1.pfc_pause_time[paused_prio] = 0;
                    waiting_for_xon = 0;
                    `uvm_info("VIRTUAL_SEQ",$sformatf(" XON sent for prio=%0d,priority_en[%0d]=%0d,pfc_pause_time[%0d]= %0d", paused_prio,
                        seq1.temp_pcp,seq1.priority_en_vector[paused_prio], seq1.temp_pcp,seq1.pfc_pause_time[paused_prio]),UVM_LOW)
                  end 
                  pkt_gap_cnt=2;
                end
                else if(pfc_overlap_en) begin //independent_priority_overlap
                  if(!vlan_phase) begin
                    if(paused_pcp_q1.size()==0) begin
                      paused_pcp_q1='{0,1,2,3,4,5,6,7};
                      paused_pcp_q1.shuffle();
                    end 
                    else begin
                      seq1.pfc_sel=1;
                      seq1.pfc_overlap_en=pfc_overlap_en;
                      seq1.temp_pcp=paused_pcp_q1.pop_back();
                      seq1.priority_en_vector[seq1.temp_pcp]=1;
                      for(int i=0;i<8;i++) 
                        seq1.pfc_pause_time[i]=$urandom_range(5,10);
                      if(paused_pcp_q1.size()==0) begin
                        vlan_phase=1;
                        pause_gap_cnt=$urandom_range(50,100);
                        this.pfc_overlap_en=0;
                      end  
                    end
                  end 
                end 
                else if(pfc_stress_en && (seq1.pfc_sel || pcp_rand_en)) begin
                  if(!pcp_rand_en) begin
		    assert(pcp_gen.randomize());
                    seq1.temp_pcp= pcp_gen.rand_pcp;
                    t_pcp = seq1.temp_pcp;
                    pcp_rand_en = 1;
                    t_cnt = count;
                  end
                  seq1.temp_pcp = t_pcp;
                  //seq1.pfc_sel = pcp_rand_en;
                  seq1.priority_en_vector[seq1.temp_pcp] = 1;      
                  seq1.pfc_pause_time[seq1.temp_pcp]     = 10;                
                  if(count == t_cnt+1) seq1.pfc_pause_time[seq1.temp_pcp]=6;                
                  else if(count == t_cnt+2) seq1.pfc_pause_time[seq1.temp_pcp]=3;                
                  else if(count == t_cnt+3) begin
                    seq1.pfc_pause_time[seq1.temp_pcp]=0;                
                    pcp_rand_en = 0;
                  end
                  `uvm_info("Sending Stress",$sformatf("Sending PFC with PCP = %0d, Pause Time = %0d, Count = %0d, Pause_en_vector = %0d",
                    seq1.temp_pcp,seq1.pfc_pause_time[seq1.temp_pcp], count ,seq1.priority_en_vector[seq1.temp_pcp]),UVM_LOW)
                end 
                else if(multiple_pfc_stress_en && count >=2 && count <=9) begin      
                  set_multiple_pfc_stress(count, seq1);
                end        
                else begin
                  seq1.pfc_sel = 0;
                  pause_gap_cnt--;
                  if(pause_gap_cnt==0) begin
                    vlan_phase = 0;
                    pfc_overlap_en=1;
                  end  
                end  
                count++;
                seq1.start(p_sequencer.mac_seqr_h[0]);
              end
            end
            begin
              repeat(this.no_of_pkts) begin
                seq2 = gmii_eth_normal_frame_seq::type_id::create ($sformatf("pfc_seq_%0d",$time));
                apply_config(seq2);
                seq2.basic_pfc_en=this.basic_pfc_en;
                seq2.pfc_rand_pri_en=this.pfc_rand_pri_en;
                if(seq2_pcp_en) begin
                  seq2.temp_pcp=pcp_temp;
                  seq2_pcp_en=0;
                end 
                if(simul_pfc_en2) begin
                  seq2.pfc_sel=1;
		  assert(pcp_gen.randomize());
                  seq2.temp_pcp=pcp_gen.rand_pcp;
                  paused_pcp_q2.push_back(seq2.temp_pcp);
                  seq2.priority_en_vector[seq2.temp_pcp]=1;
		  for(int i=0;i<=7;i++) begin
                    seq2.pfc_pause_time[seq2.temp_pcp]=$urandom_range(1,10);
	          end
                  `uvm_info("seqqq_mac1",$sformatf("pcp=%0d, pfc_pause_time=%0d",seq2.temp_pcp,seq2.pfc_pause_time[seq2.temp_pcp]),UVM_LOW)
                  simul_pfc_en2=0;
                  if($urandom_range(1,50)<=30) begin
		    assert(pcp_gen.randomize());
                    temp=pcp_gen.rand_pcp;
                    if(temp inside {paused_pcp_q2})
                      seq2.pfc_pause_time[temp]=0;
                  end  
                end
                else begin
                  if(waiting_for_xon && $urandom_range(1,10)<5) begin
                    seq2.force_pcp_en = 1;
                    seq2.force_pcp = paused_prio;
                  end
                  else begin
                    seq2.force_pcp_en = 0;
                  end
                  seq2.pfc_sel =0;
                end 
                seq2.start(p_sequencer.mac_seqr_h[1]);
              end
            end
          join
        end
      end
    end
  endtask

  task set_multiple_pfc_stress(ref int count, ref gmii_eth_normal_frame_seq seq1);
    seq1.pfc_sel=1;    
    if(count % 2 == 0) begin
      seq1.temp_pcp=3;//$urandom_range(1,4);
    end
    else begin
      seq1.temp_pcp=4;//$urandom_range(1,4);
    end
    seq1.priority_en_vector[seq1.temp_pcp] = 1;// priority[3]      
    if(count == 2 || count == 3) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=10;                
    end
    else if(count == 4 || count == 5) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=6;                
    end
    else if(count == 6 || count == 7) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=3;                
    end
    else begin
      seq1.pfc_pause_time[seq1.temp_pcp]=0;                
    end
  endtask

  //Applying config values for virtual seq to sequence
  task apply_config(ref gmii_eth_normal_frame_seq seq);
    seq.pkt_no                = this.set_corpt_pkt;
    seq.c_ether_type          = this.ether_type;
    seq.err_b                 = this.err_b;
    seq.err_offset            = this.err_offset;
    seq.vlan_en               = this.vlan_en;
    seq.TPID                  = this.TPID;
    seq.payload_rand_en       = this.payload_rand_en;
    seq.corrupt_preamble_en   = this.corrupt_preamble_en;
    seq.mode                  = this.mode;
    seq.corrupt_fcs_en        = this.corrupt_fcs_en;
    seq.custom_da             = this.custom_da;  
    seq.da                    = this.da;
    seq.VID                   = this.VID;    
    seq.invld_length_en       = this.invld_length_en;
    seq.len_payload_mismat_en = this.len_payload_mismat_en; 
    seq.corrupt_ipg_en        = this.corrupt_ipg_en;
    seq.error_pkt_no          = this.error_pkt_no;
    seq.padding_en            = this.padding_en;
    seq.pause_rsd_en          = this.pause_rsd_en;
    seq.middle_coll_en        = this.middle_coll_en;
    seq.max_coll_en           = this.max_coll_en;
    seq.constant_rand_slot    = this.constant_rand_slot;
    seq.late_coll_en          = this.late_coll_en;
    seq.burst_en              = this.burst_en;
    seq.runt_en               = this.runt_en;
    seq.runt_bad_en           = this.runt_bad_en;
  endtask   
endclass


