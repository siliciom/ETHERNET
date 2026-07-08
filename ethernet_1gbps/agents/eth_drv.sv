class eth_drv extends uvm_driver#(eth_seq_item);
  `uvm_component_utils(eth_drv);
  `uvm_register_cb(eth_drv, error_cb)  
  eth_seq_item tr;
  virtual eth_gmii_interface v_intf;

  bit [`INTF_BIT_WIDTH-1:0] frame_q[$];
  bit [`INTF_BIT_WIDTH-1:0] retry_q[$];
  int indx;
  bit [31:0] next_crc32;
  logic [31:0] c;
  int idx;
  bit [47:0] mac_addr;
  bit collision_detect;
  int retry_count;
  int backoff_k;
  int rand_slot;
  int backoff_time;     
  int pad_cnt;
  bit frame_in_progress = 0;
  int PAUSE_QUANTA_CYCLES;
  bit mid_en;
  bit first_pkt;
  eth_seq_item pause_hold_q[$];
  eth_seq_item pfc_hold_q[8][$];
  int resumed_pcp_q[$];
  semaphore tx_sem;
  bit[2:0] current_tx_pcp;
  bit current_tx_vlan_en=0;
  bit drain_in_progress[8];
  bit pause_drain_in_progress=0;
 
  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name,parent);
  endfunction   
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    if(!uvm_config_db#(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW) 
      
    PAUSE_QUANTA_CYCLES = (512 / $bits(v_intf.drv_cb.TXD));   
    tx_sem = new(1); 
  endfunction    
  
  task run_phase(uvm_phase phase);
    drive_reset();
    reset_counters();
    wait(v_intf.rst);
   
    fork
      pause_timer();
      pfc_timer();
      drain_resumed_frames();
      drain_pause_queue();
      update_counters();
    join_none  

    forever begin    
      wait(statistics::pause_flag[mac_addr]==0);
      seq_item_port.get_next_item(tr);
      if(tr.vlan_en && (statistics::pfc_flag[mac_addr][tr.PCP] || drain_in_progress[tr.PCP])) begin
       pfc_hold_q[tr.PCP].push_back(tr);
       `uvm_info("PFC_HOLD_Q",$sformatf("pcp=%d mac_addr=%h pushed",
                tr.PCP,mac_addr),UVM_LOW)
       `uvm_info("HOLD_Q",$sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p",tr.vlan_en,tr.PCP,tr.ether_type,tr.payload),UVM_LOW)
      end
      else if(statistics::pause_flag[mac_addr]) begin
        pause_hold_q.push_back(tr);
        `uvm_info("PAUSE_HOLD_Q",
                   $sformatf("mac_addr=%h frame queued during pause, size=%0d", mac_addr, pause_hold_q.size()),UVM_LOW)
        tx_sem.put(1);
      end
      else begin
        tx_sem.get(1);
        wait_for_drain_complete(.hold_sem(1));
        if(tr.vlan_en && statistics::pfc_flag[mac_addr][tr.PCP]) begin
          pfc_hold_q[tr.PCP].push_back(tr);
          `uvm_info("Re_PFC_HOLD_Q",$sformatf("pcp=%d pushed", tr.PCP), UVM_LOW)
          `uvm_info("HOLD_Q",$sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p",tr.vlan_en,tr.PCP,tr.ether_type,tr.payload),UVM_LOW)
          tx_sem.put(1);
        end
	else if(statistics::pause_flag[mac_addr]) begin        
          pause_hold_q.push_back(tr);
          `uvm_info("Re_PAUSE_HOLD_Q",$sformatf("mac=%h re-queued after sem grant",mac_addr),UVM_LOW)
          tx_sem.put(1);
        end
        else begin
          frame_pack(tr);
          retry_q = frame_q;
          drive_tx_frame(tr); 
          tx_sem.put(1);
        end
      end
      seq_item_port.item_done();
    end  
  endtask
  //pause_timer_task
  task pause_timer();
    int local_pause_cycles;
    int prev_pause_value;
    forever begin
      wait(statistics::pause_flag[mac_addr] == 1);
      @(v_intf.drv_cb);
      wait(frame_in_progress == 0);
      prev_pause_value = statistics::pause_value[mac_addr];
      local_pause_cycles = prev_pause_value * PAUSE_QUANTA_CYCLES;
      `uvm_info("PAUSE_DBG", $sformatf("mac=%0d remaining=%0d pause_value=%0d update=%0b",
               mac_addr[7:0], local_pause_cycles, statistics::pause_value[mac_addr], statistics::pause_update[mac_addr]), UVM_LOW)
      while(local_pause_cycles > 0 ) begin
        @(v_intf.drv_cb);
        v_intf.drv_cb.TX_EN <= 0;
        v_intf.drv_cb.TXD   <= 0;
        v_intf.drv_cb.TX_ER <= 0;
        if(statistics::pause_update[mac_addr]) begin
          prev_pause_value = statistics::pause_value[mac_addr];
          local_pause_cycles = prev_pause_value * PAUSE_QUANTA_CYCLES;
          statistics::pause_update[mac_addr] =0;
          `uvm_info("PAUSE_UPDATE", $sformatf("Pause updated new=%0d",local_pause_cycles), UVM_LOW)
        end
        else begin
          local_pause_cycles--;
        end
      end
      statistics::pause_flag[mac_addr] = 0;
      `uvm_info("PAUSE", $sformatf("TX Resume mac_id=%0d",mac_addr[7:0]), UVM_LOW)
    end
  endtask
  
  //pfc_timer_task
  task pfc_timer();
    int local_pfc_cycles[8];
    int prev_pfc_value[8];
    bit pfc_pending[8];
    bit pfc_just_started[8];
    forever begin
      @(v_intf.drv_cb);
      for(int i=0; i<8; i++) begin
        if(pfc_pending[i] && !(frame_in_progress && current_tx_vlan_en && current_tx_pcp == i)) begin
          pfc_pending[i]                           = 0;
          prev_pfc_value[i]                        = statistics::pfc_value[mac_addr][i];
          local_pfc_cycles[i]                      = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
          pfc_just_started[i]=1;
          statistics::pfc_update[mac_addr][i]      = 0;
          `uvm_info("PFC_TIMER_START", $sformatf("pcp=%0d start_time=%0t", i, $time), UVM_LOW)
        end
        // Fresh PFC flag
        if(statistics::pfc_flag[mac_addr][i] && local_pfc_cycles[i]==0 && !pfc_pending[i]) begin
          `uvm_info("DRV_TIMER_START", $sformatf("pcp=%0d pfc_value=%0d", i, statistics::pfc_value[mac_addr][i]), UVM_LOW)
          // XON (pfc_value == 0)
          if(statistics::pfc_value[mac_addr][i] == 0) begin
            local_pfc_cycles[i] = 0;
            statistics::pfc_flag[mac_addr][i] = 0;
            statistics::pfc_update[mac_addr][i] = 0;
            push_resumed_pcp(i);
          end
          // Frame in progress for this priority
          else if(frame_in_progress && current_tx_vlan_en && current_tx_pcp == i) begin
            pfc_pending[i] = 1;  
            `uvm_info("PFC_WAIT", $sformatf("pcp=%0d frame in progress, deferring timer start", i), UVM_LOW)
          end
          else begin
            prev_pfc_value[i] = statistics::pfc_value[mac_addr][i];
            local_pfc_cycles[i] = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
            pfc_just_started[i]=1;
            statistics::pfc_update[mac_addr][i] = 0;
            `uvm_info("PFC_TIMER_START",$sformatf("pcp=%0d start_time=%0t", i, $time), UVM_LOW)
          end
        end
      end
      // TIMER RUNNING
      for(int i=0;i<8;i++) begin
        if(local_pfc_cycles[i] > 0) begin
          if(statistics::pfc_update[mac_addr][i])begin
            //Xon update
            if(statistics::pfc_value[mac_addr][i]==0) begin            		   
	      prev_pfc_value[i]=statistics::pfc_value[mac_addr][i];		   
	      local_pfc_cycles[i] =0;
	      statistics::pfc_flag[mac_addr][i] = 0;
              `uvm_info("DRV_TIMER",$sformatf("local=%0d,i=%0d",local_pfc_cycles[i],i),UVM_LOW) statistics::pfc_update[mac_addr][i]=0;
              push_resumed_pcp(i);   
              continue;
            end 
            else begin
	      prev_pfc_value[i] = statistics::pfc_value[mac_addr][i];
              local_pfc_cycles[i] = prev_pfc_value[i]*PAUSE_QUANTA_CYCLES;
	     	statistics::pfc_update[mac_addr][i]=0;
	      pfc_just_started[i] = 1;
            end
          end 
          if(pfc_just_started[i]) begin
            `uvm_info("DRV_TIMER",$sformatf("local=%0d,i=%0d",local_pfc_cycles[i],i),UVM_LOW)
             pfc_just_started[i]=0;
             continue ;
          end     
          local_pfc_cycles[i]--;
          `uvm_info("DRV_TIMER",$sformatf("local=%0d,i=%0d",local_pfc_cycles[i],i),UVM_LOW)
          if(local_pfc_cycles[i] == 0) begin
            statistics::pfc_flag[mac_addr][i] = 0;
            prev_pfc_value[i] = 0;
            push_resumed_pcp(i);
          end
        end
      end
    end
  endtask
  
  task drain_resumed_frames();
    forever begin
      int pcp;
      wait(resumed_pcp_q.size() > 0);
      pcp = resumed_pcp_q.pop_front();
      if(drain_in_progress[pcp]) begin
       `uvm_info("DRAIN_SKIP",
        $sformatf("pcp=%0d already draining — existing thread will pick up new frames", pcp),
        UVM_LOW)
      end
      else begin
      	fork
          begin
            automatic int my_pcp = pcp;
            drain_one_pcp(my_pcp);
          end
        join_none
      end
    end
  endtask 
  task drain_one_pcp(int pcp);
    eth_seq_item local_tr;
    if(pfc_hold_q[pcp].size() > 0) begin
      drain_in_progress[pcp] = 1;
      `uvm_info("DRAIN_START",$sformatf("pcp=%0d frames=%0d drain_in_progress[%0d]=1", pcp, pfc_hold_q[pcp].size(), pcp), UVM_LOW)
    end
    while(pfc_hold_q[pcp].size() > 0) begin
      if(statistics::pfc_flag[mac_addr][pcp]) begin
        drain_in_progress[pcp] = 0;
        `uvm_info("PFC_REBLOCK_EXIT", $sformatf("pcp=%0d re-XOFF mid-drain — exiting, will resume via resumed_pcp_q", pcp), UVM_LOW)
        return;
      end
      local_tr = pfc_hold_q[pcp].pop_front();
      tx_sem.get(1);
      if(statistics::pfc_flag[mac_addr][pcp]) begin
        pfc_hold_q[pcp].push_front(local_tr);
        tx_sem.put(1);
        continue;
      end
      frame_pack(local_tr);
      retry_q = frame_q;
      `uvm_info("RESUMED_PFC","",UVM_LOW)
      drive_tx_frame(local_tr);
      tx_sem.put(1);
    end
    drain_in_progress[pcp] = 0;
    `uvm_info("DRAIN_DONE","",UVM_LOW)
  endtask
  task wait_for_drain_complete(bit hold_sem = 0);
    bit any_draining;
    forever begin
      any_draining = 0;
      // check all 8 priority queues
      for(int i = 0; i < 8; i++) begin
        if(pfc_hold_q[i].size() > 0 && !statistics::pfc_flag[mac_addr][i]) begin
          any_draining = 1;
          `uvm_info("DRV_YIELD",$sformatf("pcp=%0d draining (%0d frames) — new frame waiting",
           i, pfc_hold_q[i].size()), UVM_LOW)
          break;
        end
      end
      // also check resumed_pcp_q entries
      if(!any_draining && resumed_pcp_q.size() > 0) begin
        foreach(resumed_pcp_q[k]) begin
          if(pfc_hold_q[resumed_pcp_q[k]].size() > 0) begin
            any_draining = 1;
            `uvm_info("DRV_YIELD_RESUMEQ",$sformatf("resumed_pcp_q has pcp=%0d with %0d frames pending", resumed_pcp_q[k], pfc_hold_q[resumed_pcp_q[k]].size()), UVM_LOW)
            break;
          end
        end
      end
      if (!any_draining) break;          
      if (hold_sem) tx_sem.put(1);      
      @(v_intf.drv_cb);
      if (hold_sem) tx_sem.get(1);       
    end
  endtask

  task push_resumed_pcp(int pcp);
    foreach(resumed_pcp_q[k]) begin
      if(resumed_pcp_q[k] == pcp) begin
        `uvm_info("RESUMED_DUP",
          $sformatf("pcp=%0d already in resumed_pcp_q — skipped", pcp), UVM_LOW)
        return;
      end
    end
    resumed_pcp_q.push_back(pcp);
    `uvm_info("RESUMED_PUSH",
      $sformatf("pcp=%0d pushed, q_size=%0d", pcp, resumed_pcp_q.size()), UVM_LOW)
  endtask

  task drive_reset();
    v_intf.drv_cb.TXD    <= 0;
    v_intf.drv_cb.TX_ER  <= 0;
    v_intf.drv_cb.TX_EN  <= 0;
  endtask
    
  task carrier_ext();
    if(tr.mode == 0 && idx < 512) begin
      for(int i = idx; i < 512; i++) begin
        @(v_intf.drv_cb);         
        v_intf.drv_cb.TX_EN <= 0;      
        v_intf.drv_cb.TXD   <= 8'h0F;
        v_intf.drv_cb.TX_ER <= 1;
	      idx++;	
      end
      `uvm_info("CARR_EXT",$sformatf("Sending Carrer Extension for %0d bytes",idx),UVM_LOW);
    end    
  endtask

  task drain_pause_queue();
    forever begin
    eth_seq_item local_tr;
    wait(pause_hold_q.size() > 0);
    wait(statistics::pause_flag[mac_addr] == 0);
    pause_drain_in_progress = 1;
    `uvm_info("PAUSE_DRAIN_START",
      $sformatf("mac=%h frames=%0d", mac_addr, pause_hold_q.size()), UVM_LOW)
 
    while(pause_hold_q.size() > 0) begin
      tx_sem.get(1);
      if(statistics::pause_flag[mac_addr]) begin
        tx_sem.put(1);
        `uvm_info("PAUSE_REBLOCK","pause reasserted mid-drain",UVM_LOW)
        break;                          
      end
      local_tr = pause_hold_q.pop_front();
      frame_pack(local_tr);
      retry_q = frame_q;
      drive_tx_frame(local_tr);
      tx_sem.put(1);
    end
 
    if(pause_hold_q.size() == 0) begin
      pause_drain_in_progress = 0;
      `uvm_info("PAUSE_DRAIN_DONE","all held frames sent",UVM_LOW)
    end
   end
  endtask
  
  function void phase_ready_to_end(uvm_phase phase);
    bit all_done;
    all_done = 1;

    // check 1: any PFC timer still active?
    for(int i = 0; i < 8; i++) begin
      if(statistics::pfc_flag[mac_addr][i]) begin
        all_done = 0;
        break;
      end
    end
    //check 2: any held frames still in queue?
    for(int i = 0; i < 8; i++) begin
      if(pfc_hold_q[i].size() > 0) begin
        all_done = 0;
        break;
      end
    end
    // check 3: any pending resumes not yet drained?
    if(resumed_pcp_q.size() > 0)
      all_done = 0;
    if(!all_done) begin
      phase.raise_objection(this, "PFC timers/queues still pending");
      fork
        begin
          forever begin
            all_done = 1;
            for(int i = 0; i < 8; i++) begin
              if(statistics::pfc_flag[mac_addr][i]) begin
                all_done = 0; break;
              end
            end
            for(int i = 0; i < 8; i++) begin
              if(pfc_hold_q[i].size() > 0) begin
                all_done = 0; 
		break;
              end
            end
            if(resumed_pcp_q.size() > 0)
              all_done = 0;
            if(all_done) begin
              `uvm_info("PFC_DRAIN_DONE",$sformatf("All PFC timers expired mac=%0h", mac_addr), UVM_LOW)
              phase.drop_objection(this, "PFC timers done");
              break;
            end
            @(v_intf.drv_cb);
          end
        end
      join_none
    end
  endfunction 
  
  task drive_tx_frame(eth_seq_item tr);
    int k;
     if(statistics::pause_flag[mac_addr]) begin     
       pause_hold_q.push_front(tr);
       `uvm_info("PAUSE_PREEMPT_PRECOMMIT",
          $sformatf("mac=%h pause asserted before frame_in_progress set",mac_addr),UVM_LOW)
       return;
     end
     frame_in_progress=1;
     current_tx_vlan_en=tr.vlan_en;
     current_tx_pcp=tr.PCP;
     if(!tr.mode && tr.middle_coll_en && !mid_en)
       mid_en = 1; 
     else if(!tr.mode) 
       wait(!v_intf.drv_cb.CRS);

     if(statistics::pause_flag[mac_addr]) begin     
       pause_hold_q.push_front(tr);
       `uvm_info("PAUSE_PREEMPT_PRECOMMIT", $sformatf("mac=%h pause asserted before frame_in_progress set",mac_addr),UVM_LOW)
       return;
    end

    for (int j = 0; j < idx; j++) begin
      @(v_intf.drv_cb); 
      if(j >= 8) begin
	k = j-8;
        if(tr.late_coll_en && k == tr.coll_byte && collision_detect == 0) begin
          v_intf.COL <= 1;
          `uvm_info("Late collision", $sformatf("Late collision in byte = %0d", k), UVM_LOW)
        end
        else
	  v_intf.COL <= 0;	
      end
      if(v_intf.drv_cb.COL == 1 && k < 64) begin
        frame_q.delete();
        collision_detect = 1;
        break;
      end 
      else
	collision_detect = 0;
      if(j==0 && tr.vlan_en) begin
       if(statistics::pfc_flag[mac_addr][tr.PCP]) begin
         frame_q.delete();     
         frame_in_progress = 0;
         collision_detect  = 0;
         pfc_hold_q[tr.PCP].push_back(tr);
        `uvm_info("PFC_HOLD_Q",$sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p",tr.vlan_en,tr.PCP,tr.ether_type,tr.payload),UVM_LOW)
        return; 
       end
      end 	
      if(j==0 ) begin
        if(statistics::pause_flag[mac_addr]) begin
          frame_q.delete();
          frame_in_progress=0;
          pause_hold_q.push_front(tr);
          `uvm_info("pppppppppppppppppppppppppppppp","",UVM_LOW)
           return;
        end
      end 
      v_intf.drv_cb.TX_EN <= 1;      
      v_intf.drv_cb.TXD   <= frame_q.pop_front();
      v_intf.drv_cb.TX_ER <= 0;
      if(tr.err_b == 1 && j >= tr.err_offset) begin
        v_intf.drv_cb.TX_ER <= 1;
      end    
    end
    v_intf.COL <= 0;      
    if(collision_detect == 1) begin
      send_jam_signal();
      do_back_off_alg(tr);
    end
    else begin
      retry_q.delete();
      retry_count    = 0;
      backoff_k      = 0; 
      rand_slot      = 0;  
      backoff_time   = 0;    
    end
    //Adding Carrier Extension if it is less than 512 bytes
    if(!tr.mode && !first_pkt) carrier_ext();
    if(!tr.mode && tr.burst_en && first_pkt == 0) first_pkt = 1;
    
    //Driving IPG
    frame_in_progress =0;  
    send_ipg();
  endtask    

  task send_ipg();
    for(int j = 0;j < tr.ipg_cnt; j++) begin  //8 bits wide * 12 clock = 96-bit times
      @(v_intf.drv_cb);
      v_intf.drv_cb.TXD   <= 0;
      v_intf.drv_cb.TX_EN <= 0;
      v_intf.drv_cb.TX_ER <= 0;      
    end
  endtask  

  task send_jam_signal();
    for(int i = 0; i < 4;i++) begin //Sending 32-bit jam signal                 
      v_intf.drv_cb.TX_EN <= 1;      
      v_intf.drv_cb.TXD   <= 8'hFF; //Jam Pattern
      v_intf.drv_cb.TX_ER <= 0;    
      @(v_intf.drv_cb);
    end
    drive_reset();
  endtask
    
  task do_back_off_alg(eth_seq_item tr);
    // Ethernet limits
    int SLOT_TIME       = 512; // bit times
    int MAX_BACKOFF_EXP = 10;
    int MAX_RETRY       = 16;

    // Increment retry count after collision
    retry_count++;     
    // Retry limit check
    if (retry_count >= MAX_RETRY) begin
      retry_count    = 0;
      backoff_k      = 0; 
      rand_slot      = 0;  
      backoff_time   = 0;   	    
      return;
    end

    if (retry_count < MAX_BACKOFF_EXP)
      backoff_k = retry_count;
    else
      backoff_k = MAX_BACKOFF_EXP;

    // Random slot selection
    // Range: 0 to (2^k - 1)
    if(tr.max_coll_en == 1)
      rand_slot = tr.constant_rand_slot;
    else
      rand_slot = $urandom_range((2**backoff_k)-1, 0);

    // Backoff delay
    backoff_time = rand_slot * SLOT_TIME;

    `uvm_info(get_type_name(), 
     $sformatf({"\n-----------------------------------",
               "\nRetry Count  : %0d",
               "\nBackoff k    : %0d",
               "\nRandom Slot  : %0d",
               "\nBackoff Time : %0d bit-times",
               "\n-----------------------------------"}, 
     retry_count, backoff_k, rand_slot, backoff_time), 
     UVM_LOW)

    // Wait for backoff time
    #(backoff_time);
    send_ipg();
    frame_q = retry_q;
    drive_tx_frame(tr);
   
  endtask
    
  task frame_pack(ref eth_seq_item tr);
    mid_en = 0;
    idx = 0;

    //Calling callbacks
    `uvm_do_callbacks(eth_drv, error_cb, inject_error(tr));

    //Preamble packing
    foreach(tr.preamble[i])
      frame_q[idx++] = tr.preamble[i];
    
    //SFD Packing
    frame_q[idx++] = tr.sfd[7:0];
    
    //DA packing
    for(int i = 5; i >= 0; i--)
      frame_q[idx++] = tr.da[i*8 +: 8];
    
    //SA packing
    for(int i = 5; i >= 0; i--) //6 bytes of Source Address
      frame_q[idx++] = tr.sa[i*8 +: 8];
    
    //If VLAN TAG is Enable, vlan fields packing
    if(tr.vlan_en == 1) begin
      frame_q[idx++] = tr.TPID[15:8];
      frame_q[idx++] = tr.TPID[7:0];      
      frame_q[idx++] = {tr.PCP, tr.DEI, tr.VID[11:8]};
      frame_q[idx++] = tr.VID[7:0];      
    end      
    
    //Type/Length packing
    frame_q[idx++] = tr.ether_type[15:8];    
    frame_q[idx++] = tr.ether_type[7:0];
    
    if(tr.pause_frame_en || tr.pfc_frame_en) begin //Pause Frame Packing
      frame_q[idx++] = tr.pause_opc[15:8];
      frame_q[idx++] = tr.pause_opc[7:0];
      if(tr.pfc_frame_en) begin // logic for pfc frame
        frame_q[idx++] = tr.priority_en_vector[15:8];
        frame_q[idx++] = tr.priority_en_vector[7:0];
        for(int i=0;i<8; i++) begin
          frame_q[idx++]=tr.pfc_pause_time[i][15:8];
          frame_q[idx++]=tr.pfc_pause_time[i][7:0];
        end
        //payload
         for(int i = 0; i<26; i++)
           frame_q[idx++] = 8'h00;
         `uvm_info("DRIVING DATA", $sformatf("\n\t da=%h\n\t sa=%h\n\t type=%0h\n\t opcode=%0h\n\t priority_en_vector=%0d \n\t pfc_pause_time=%p 
		\n\t payload=%0d\n\t Frame size=%0d",tr.da, tr.sa, tr.ether_type, tr.pause_opc,tr.priority_en_vector, tr.pfc_pause_time, tr.payload.size(), idx), UVM_LOW) 
      end
      else begin // logic for pause frame
        frame_q[idx++] = tr.pause_time[15:8];
        frame_q[idx++] = tr.pause_time[7:0];
        for(int i = 0; i< 42;i++)
          frame_q[idx++] = 0;
        `uvm_info("DRIVING DATA", $sformatf("pause_frame_en=%0b,da=%p,sa=%p,type=%0h,opcode=%0h,payload=%0d,Frame size = %0d",
	      tr.pause_frame_en,tr.da,tr.sa,tr.ether_type,tr.pause_opc,tr.payload.size(),idx),UVM_LOW)
      end
    end    
    else begin
      //Payload packing
      for(int i = (tr.payload.size()- 1);i >= 0 ;i--)
        frame_q[idx++] = tr.payload[i];
      //Zero Padding if payload is less than 46 bytes for normal frame and
	// bytes for vlan tagged frame
      if(tr.vlan_en == 1)
        pad_cnt = 42;
      else
        pad_cnt = 46;
      
      if(tr.payload.size() < pad_cnt && tr.padding_en == 1) begin
        for(int i = tr.payload.size(); i < pad_cnt; i++)
          frame_q[idx++] = 0;
      end
    end
    
    //CRC packing
    next_crc32 = 32'hFFFFFFFF;
    for(int i = 0;i < idx;i++) begin
      if(i > 7) //Avoiding the Preamble and SFD Bytes
        next_crc32 = tr.crc_32(next_crc32, frame_q[i]);
    end
    
    next_crc32 = ~next_crc32;
    
    //BAD FCS
    if(tr.corrupt_fcs_en == 1) begin
      next_crc32[7:0] = ~next_crc32[7:0];
      `uvm_info("BAD FCS",$sformatf(" Transmitting Incorrect CRC = %h",next_crc32),UVM_LOW)      
    end
    
    for(int i = 3;i >= 0;i--)
      frame_q[idx++] = next_crc32[8*i +: 8]; 
    
    // Print full frame format always
    $display("*****************************ETH_DRIVER***********************************");
    `uvm_info("DRIVER PACKING", $sformatf("\n\t preamble = %p\n\t sfd = 0x%0h\n\t DA = %h\n\t SA = %h\n\t ether_type = 0x%0h\n\t payload = %h bytes\n\t crc = 0x%h\n\t Total frame size = %0d, Frame size from DA = %0d\n\t Payload size = %0d\n\n\t VLAN_EN = %b\n\t VLAN_TPID = %h\n\t PCP = %h, DEI = %h, VID = %h",tr.preamble, tr.sfd, tr.da, tr.sa,tr.ether_type, tr.payload.size(), next_crc32,idx,idx - 8,tr.payload.size(),tr.vlan_en, tr.TPID, tr.PCP,tr.DEI,tr.VID), UVM_LOW)
    
    `uvm_info("DRIVING DATA", $sformatf("Frame size = %0d, CRC = %h",idx,next_crc32),UVM_LOW);
  endtask
  
  task update_counters();
    forever begin
      @(posedge v_intf.TX_CLK);
       statistics::v_uif[mac_addr].tx_good_pkt_count      = statistics::tx_good_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_bad_pkt_count       = statistics::tx_bad_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_collision_count     = statistics::tx_collision_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_unicast_count       = statistics::tx_unicast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_multicast_count     = statistics::tx_multicast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_broadcast_count     = statistics::tx_broadcast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_fragment_count      = statistics::tx_fragment_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_runt_count          = statistics::tx_runt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_count         = statistics::tx_pause_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_vlan_count          = statistics::tx_vlan_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_jumbo_count         = statistics::tx_jumbo_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_jabber_count        = statistics::tx_jabber_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_ipg_violation_count = statistics::tx_ipg_violation_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_count       = statistics::tx_pfc_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_count      = statistics::tx_pfc_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_carrier_ext_count   = statistics::tx_carrier_ext_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_xon_count     = statistics::tx_pause_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_xoff_count    = statistics::tx_pause_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_control_pkt_count   = statistics::tx_control_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count = statistics::tx_pfc_xon_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count = statistics::tx_pfc_xon_prio1_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count = statistics::tx_pfc_xon_prio2_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count = statistics::tx_pfc_xon_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count = statistics::tx_pfc_xon_prio4_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count = statistics::tx_pfc_xon_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count = statistics::tx_pfc_xon_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count = statistics::tx_pfc_xon_prio7_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count= statistics::tx_pfc_xoff_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count= statistics::tx_pfc_xoff_prio1_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count= statistics::tx_pfc_xoff_prio2_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count= statistics::tx_pfc_xoff_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count= statistics::tx_pfc_xoff_prio4_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count= statistics::tx_pfc_xoff_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count= statistics::tx_pfc_xoff_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count= statistics::tx_pfc_xoff_prio7_pending[mac_addr];

       statistics::v_uif[mac_addr].rx_good_pkt_count      = statistics::rx_good_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_bad_pkt_count       = statistics::rx_bad_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_collision_count     = statistics::rx_collision_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_unicast_count       = statistics::rx_unicast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_multicast_count     = statistics::rx_multicast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_broadcast_count     = statistics::rx_broadcast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_fragment_count      = statistics::rx_fragment_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_runt_count          = statistics::rx_runt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_count         = statistics::rx_pause_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_vlan_count          = statistics::rx_vlan_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_jumbo_count         = statistics::rx_jumbo_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_jabber_count        = statistics::rx_jabber_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_ipg_violation_count = statistics::rx_ipg_violation_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_count       = statistics::rx_pfc_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_count      = statistics::rx_pfc_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_carrier_ext_count   = statistics::rx_carrier_ext_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_xon_count     = statistics::rx_pause_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_xoff_count    = statistics::rx_pause_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_control_pkt_count   = statistics::rx_control_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count = statistics::rx_pfc_xon_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count = statistics::rx_pfc_xon_prio1_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count = statistics::rx_pfc_xon_prio2_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count = statistics::rx_pfc_xon_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count = statistics::rx_pfc_xon_prio4_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count = statistics::rx_pfc_xon_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count = statistics::rx_pfc_xon_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count = statistics::rx_pfc_xon_prio7_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count= statistics::rx_pfc_xoff_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count= statistics::rx_pfc_xoff_prio1_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count= statistics::rx_pfc_xoff_prio2_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count= statistics::rx_pfc_xoff_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count= statistics::rx_pfc_xoff_prio4_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count= statistics::rx_pfc_xoff_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count= statistics::rx_pfc_xoff_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count= statistics::rx_pfc_xoff_prio7_pending[mac_addr];
    end
  endtask
  function void reset_counters();
    statistics::v_uif[mac_addr].tx_good_pkt_count      = 0;
    statistics::v_uif[mac_addr].tx_bad_pkt_count       = 0;
    statistics::v_uif[mac_addr].tx_collision_count     = 0;
    statistics::v_uif[mac_addr].tx_unicast_count       = 0;
    statistics::v_uif[mac_addr].tx_multicast_count     = 0;
    statistics::v_uif[mac_addr].tx_broadcast_count     = 0;
    statistics::v_uif[mac_addr].tx_fragment_count      = 0;
    statistics::v_uif[mac_addr].tx_runt_count          = 0;
    statistics::v_uif[mac_addr].tx_pause_count         = 0;
    statistics::v_uif[mac_addr].tx_vlan_count          = 0;
    statistics::v_uif[mac_addr].tx_jumbo_count         = 0;
    statistics::v_uif[mac_addr].tx_jabber_count        = 0;
    statistics::v_uif[mac_addr].tx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_count       = 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_count      = 0;
    statistics::v_uif[mac_addr].tx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].tx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].tx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].tx_control_pkt_count   = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count= 0;

    statistics::v_uif[mac_addr].rx_good_pkt_count      = 0;
    statistics::v_uif[mac_addr].rx_bad_pkt_count       = 0;
    statistics::v_uif[mac_addr].rx_unicast_count       = 0;
    statistics::v_uif[mac_addr].rx_multicast_count     = 0;
    statistics::v_uif[mac_addr].rx_broadcast_count     = 0;
    statistics::v_uif[mac_addr].rx_fragment_count      = 0;
    statistics::v_uif[mac_addr].rx_runt_count          = 0;
    statistics::v_uif[mac_addr].rx_pause_count         = 0;
    statistics::v_uif[mac_addr].rx_vlan_count          = 0;
    statistics::v_uif[mac_addr].rx_jumbo_count         = 0;
    statistics::v_uif[mac_addr].rx_jabber_count        = 0;
    statistics::v_uif[mac_addr].rx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_count       = 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_count      = 0;
    statistics::v_uif[mac_addr].rx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].rx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].rx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].rx_control_pkt_count   = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count= 0;
  endfunction 
  function int mac_no(bit [47:0] mac_t);
    eth_seq_item tr;
    tr = eth_seq_item::type_id::create("tr", this);
    foreach(tr.mac_addr[i]) begin
      if(tr.mac_addr[i] == mac_addr)
	      return i;
    end
  endfunction
    
  function void report_phase(uvm_phase phase);
    string tx_rx_report;

    tx_rx_report = $sformatf(
      "\n================ COUNTER SUMMARY =================\nMAC_ADDR=%h\n",
      mac_addr);

    tx_rx_report = {tx_rx_report, $sformatf(
      "\n---------------- MAC %0d : TX COUNTERS ----------------\n", mac_no(mac_addr))};

    tx_rx_report = {tx_rx_report, $sformatf("TX Good Packets          = %0d\n", statistics::v_uif[mac_addr].tx_good_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].tx_bad_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Collision             = %0d\n", statistics::v_uif[mac_addr].tx_collision_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Unicast               = %0d\n", statistics::v_uif[mac_addr].tx_unicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Multicast             = %0d\n", statistics::v_uif[mac_addr].tx_multicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Broadcast             = %0d\n", statistics::v_uif[mac_addr].tx_broadcast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Runt                  = %0d\n", statistics::v_uif[mac_addr].tx_runt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Fragment              = %0d\n", statistics::v_uif[mac_addr].tx_fragment_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].tx_jumbo_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Jabber                = %0d\n", statistics::v_uif[mac_addr].tx_jabber_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Pause                 = %0d\n", statistics::v_uif[mac_addr].tx_pause_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX VLAN                  = %0d\n", statistics::v_uif[mac_addr].tx_vlan_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].tx_ipg_violation_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC XON               = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].tx_carrier_ext_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Pause XON             = %0d\n", statistics::v_uif[mac_addr].tx_pause_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("Tx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].tx_pause_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX control pkt           = %0d\n", statistics::v_uif[mac_addr].tx_control_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count)};


    tx_rx_report = {tx_rx_report, $sformatf(
      "---------------- MAC %0d : RX COUNTERS ----------------\n", mac_no(mac_addr))};

    tx_rx_report = {tx_rx_report, $sformatf("RX Good Packets          = %0d\n", statistics::v_uif[mac_addr].rx_good_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].rx_bad_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Unicast               = %0d\n", statistics::v_uif[mac_addr].rx_unicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Multicast             = %0d\n", statistics::v_uif[mac_addr].rx_multicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Broadcast             = %0d\n", statistics::v_uif[mac_addr].rx_broadcast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Runt                  = %0d\n", statistics::v_uif[mac_addr].rx_runt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Fragment              = %0d\n", statistics::v_uif[mac_addr].rx_fragment_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].rx_jumbo_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Jabber                = %0d\n", statistics::v_uif[mac_addr].rx_jabber_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Pause                 = %0d\n", statistics::v_uif[mac_addr].rx_pause_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX VLAN                  = %0d\n", statistics::v_uif[mac_addr].rx_vlan_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC XON               = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].rx_ipg_violation_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].rx_carrier_ext_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Pause XON             = %0d\n", statistics::v_uif[mac_addr].rx_pause_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("Rx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].rx_pause_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX control pkt           = %0d\n", statistics::v_uif[mac_addr].rx_control_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count)};
    tx_rx_report = {tx_rx_report, "\n================================================"};

    `uvm_info("COUNTER_REPORT", tx_rx_report, UVM_NONE)

  endfunction
endclass



