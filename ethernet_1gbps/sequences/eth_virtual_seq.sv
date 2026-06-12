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
  bit multicast_en = 0;
  bit broadcast_en = 0;

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
  int pause_gap_cnt=0;
  bit pause_simul_en;
  bit simul_pause_en2=0;
  bit simul_pause_time2;
  bit send_immediate_xon=0;
  bit basic_pfc_en;
  bit normal_xon_xoff_en;
 
  bit pause_rsd_en;
  bit pause_update_time_en;
  bit middle_coll_en;
  bit vlan_pause_en;
  bit max_coll_en;
  int constant_rand_slot;
  bit late_coll_en;
  bit burst_en;

  function new (string name = "base_virtual_seq");
    super.new(name);
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
    $display("---------- MODE = %0d -----------",this.mode);
    if(!pause_normal_traffic && ! pfc_with_vlan_traffic) begin // This will work in default mode

      seq1 = gmii_eth_normal_frame_seq::type_id::create("seq1");
      seq2 = gmii_eth_normal_frame_seq::type_id::create("seq2");

      // Configure sequences config variables received from test
      apply_config(seq1);
      apply_config(seq2);

      // Start only one sequence for half-duplex without collison, multicast and broadcast testcases
      if((this.mode == 0 && !coll_en) || multicast_en || broadcast_en) begin
        seq1.start(p_sequencer.mac_seqr_h[0]);
      end
      // Start two sequences in parallel
      else begin
	if(this.middle_coll_en == 1) begin
	  fork
	    seq1.start(p_sequencer.mac_seqr_h[0]);
	    #160 seq2.start(p_sequencer.mac_seqr_h[1]);
	  join        
	end else begin    
	  fork
	    seq1.start(p_sequencer.mac_seqr_h[0]);
	    seq2.start(p_sequencer.mac_seqr_h[1]);
	  join
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
		  if($urandom_range(1,100)<=4)
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
		simul_pause_time2 = $urandom_range(1,10);
	      end
	      else if(this.vlan_pause_en && $urandom_range(1,100)<7) begin
                seq1.pause_sel=1;
                seq1.pause_time=$urandom_range(1,10);
              end	      
	      else     
		seq1.pause_sel=0;
	      seq1.start(p_sequencer.mac_seqr_h[0]);
	      count++;
	    end
	  end
	  begin
	    repeat(this.no_of_pkts) begin
	      seq2 = gmii_eth_normal_frame_seq::type_id::create("seq2");
	      apply_config(seq2);
	      if(simul_pause_en2) begin
		seq2.pause_sel  = 1;
		seq2.pause_time = simul_pause_time2;
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

              seq1 = gmii_eth_normal_frame_seq::type_id::create
              ($sformatf("vlan_seq_%0d",$time));

              apply_config(seq1);
              if(basic_pfc_en && $urandom_range(1,100)<10) begin
                seq1.pfc_sel=1;	
              end  
              else
                seq1.pfc_sel = 0;
              seq1.start(p_sequencer.mac_seqr_h[0]);
              count++;
            end
          end
          begin
            repeat(this.no_of_pkts) begin

              seq2 = gmii_eth_normal_frame_seq::type_id::create
              ($sformatf("pfc_seq_%0d",$time));

              apply_config(seq2);
              seq2.pfc_sel =0;
              seq2.start(p_sequencer.mac_seqr_h[1]);
            end
          end
          join
        end
      end
    end
  endtask

  //Applying config values for virtual seq to sequence
  task apply_config(ref gmii_eth_normal_frame_seq seq);
    seq.pkt_no              = this.set_corpt_pkt;
    seq.c_ether_type        = this.ether_type;
    seq.err_b               = this.err_b;
    seq.err_offset          = this.err_offset;
    seq.vlan_en             = this.vlan_en;
    seq.TPID                = this.TPID;
    seq.payload_rand_en     = this.payload_rand_en;
    // seq.pause_frame_en      = this.pause_frame_en;
    // seq.pause_opc           = this.pause_opc;
    seq.corrupt_preamble_en = this.corrupt_preamble_en;
    seq.mode                = this.mode;
    seq.corrupt_fcs_en      = this.corrupt_fcs_en;
    seq.custom_da           = this.custom_da;  
    seq.da                  = this.da;
    seq.VID                 = this.VID;    
    seq.invld_length_en     = this.invld_length_en;
    seq.len_payload_mismat_en = this.len_payload_mismat_en; 
    seq.corrupt_ipg_en      = this.corrupt_ipg_en;
    seq.error_pkt_no        = this.error_pkt_no;
    seq.padding_en          = this.padding_en;
    seq.pause_rsd_en        = this.pause_rsd_en;
    seq.middle_coll_en      = this.middle_coll_en;
    seq.max_coll_en         = this.max_coll_en;
    seq.constant_rand_slot  = this.constant_rand_slot;
    seq.late_coll_en        = this.late_coll_en;
    seq.burst_en            = this.burst_en;

  endtask   

endclass


