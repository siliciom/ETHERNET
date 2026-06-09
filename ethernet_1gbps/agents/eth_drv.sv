class eth_drv extends uvm_driver#(eth_seq_item);
  `uvm_component_utils(eth_drv);
  eth_seq_item tr;
  virtual eth_gmii_interface v_intf;

  bit [`INTF_BIT_WIDTH-1:0] frame_q[$];
  bit [`INTF_BIT_WIDTH-1:0] retry_q[$];
  int indx;
  bit [31:0] next_crc32;
  logic [31:0] c;
  int idx;
  bit [47:0] mac_addr;
  bit mode;
  bit collision_detect;
  int retry_count;
  int backoff_k;
  int rand_slot;
  int backoff_time;     
  int pad_cnt;
  bit frame_in_progress = 0;
  int PAUSE_QUANTA_CYCLES;
 
  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name,parent);
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 

    if(!uvm_config_db#(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW) 
      
    PAUSE_QUANTA_CYCLES = (512 / $bits(v_intf.TXD));   
  
  endfunction    
  
  task run_phase(uvm_phase phase);
    drive_reset();
    wait(v_intf.rst);
   
    fork
      pause_timer();
      pfc_timer();
    join_none       
    forever begin    
      wait(statistics::pause_flag[mac_addr]==0);
      seq_item_port.get_next_item(tr);
      frame_pack(tr);
      retry_q = frame_q;
      drive_tx_frame(tr);    
      seq_item_port.item_done(); 
    end
  endtask
    
  //---------------------------------------------------
  //             pause_timer_task
  //---------------------------------------------------- 
  task pause_timer();
    int local_pause_cycles;
    int prev_pause_value;

    forever begin
      wait(statistics::pause_flag[mac_addr] == 1);
      @(posedge v_intf.TX_CLK);
      wait(frame_in_progress == 0);
      prev_pause_value = statistics::pause_value[mac_addr];
      local_pause_cycles = prev_pause_value * PAUSE_QUANTA_CYCLES;
      `uvm_info("PAUSE_DBG", $sformatf("*********************mac=%0d remaining=%0d pause_value=%0d update=%0b",
               mac_addr[7:0], local_pause_cycles, statistics::pause_value[mac_addr], statistics::pause_update[mac_addr]), UVM_LOW)

      while(local_pause_cycles > 0 ) begin
        @(posedge v_intf.TX_CLK);
        v_intf.TX_EN <= 0;
        v_intf.TXD   <= 0;
        v_intf.TX_ER <= 0;
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
  
  //---------------------------------------------------
  //             pfc_timer_task
  //---------------------------------------------------- 
  task pfc_timer();
    int local_pfc_cycles[8];
    int prev_pfc_value[8];
    forever begin
      for(int i=0; i<8; i++) begin
        if(statistics::pfc_flag[mac_addr][i] && local_pfc_cycles[i]==0) begin
	  prev_pfc_value[i] = statistics::pfc_value[mac_addr][i];
          local_pfc_cycles[i] = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
            `uvm_info("PFC_UPDATE", $sformatf("Priority=%0d pause_value=%0d pause_cycles=%0d", 
                      i, prev_pfc_value[i], local_pfc_cycles[i]), UVM_LOW)
        end
      end

      @(posedge v_intf.TX_CLK);
      // TIMER RUNNING
      for(int i=0;i<8;i++) begin
        if(local_pfc_cycles[i] > 0) begin
            if(statistics::pfc_update[mac_addr][i])begin
	      prev_pfc_value[i]=statistics::pfc_value[mac_addr][i];
	      local_pfc_cycles[i] = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
	      statistics::pfc_update[mac_addr][i]=0;
            end 
            if(frame_in_progress==0)
              local_pfc_cycles[i]--;
 
	    if(local_pfc_cycles[i] == 0) begin
	      statistics::pfc_flag[mac_addr][i] = 0;
	      prev_pfc_value[i] = 0;
	      `uvm_info("PFC_RESUME", $sformatf("Priority=%0d resumed", i), UVM_LOW)
           end
        end
      end
    end
  endtask

  task drive_reset();
    v_intf.TXD    <= 0;
    v_intf.TX_ER  <= 0;
    v_intf.TX_EN  <= 0;
  endtask
    
  task carrier_ext();
    if(tr.mode == 0 && tr.carr_ext_en == 1 && idx < 512) begin
      for(int i = idx; i < 512; i++) begin
        @(posedge v_intf.TX_CLK);         
        v_intf.TX_EN <= 0;      
        v_intf.TXD   <= 8'h0F;
        v_intf.TX_ER <= 1;
	idx++;	
      end
      `uvm_info("CARR_EXT",$sformatf("Sending Carrer Extension for %0d bytes",idx),UVM_LOW);
    end    
  endtask
  
  task pfc_check(eth_seq_item tr);
    if(tr.vlan_en) begin
      while(statistics::pfc_flag[mac_addr][tr.PCP]) begin
        `uvm_info("PFC_BLOCK", $sformatf("Blocking priority %0d transmission", tr.PCP), UVM_LOW)
         @(posedge v_intf.TX_CLK);
       end
     end
  endtask    
    
  task drive_tx_frame(eth_seq_item tr);
    pfc_check(tr);
    frame_in_progress=1;
    if(!mode) wait(!v_intf.CRS);
    for (int j = 0; j < idx; j++) begin
      @(posedge v_intf.TX_CLK); 
      if(v_intf.COL == 1) begin
        frame_q.delete();
        collision_detect = 1;
        break;
      end
      else
	collision_detect = 0;
      if(j==0)
	pfc_check(tr);	

      v_intf.TX_EN <= 1;      
      v_intf.TXD   <= frame_q.pop_front();
      v_intf.TX_ER <= 0;

      if(tr.err_b == 1 && j >= tr.err_offset) begin
        v_intf.TX_ER <= 1;
      end    
    end
      
    if(collision_detect == 1) begin
      send_jam_signal();
      do_back_off_alg(tr);
    end else begin
      retry_q.delete();
      retry_count    = 0;
      backoff_k      = 0; 
      rand_slot      = 0;  
      backoff_time   = 0;    
    end

    //Adding Carrier Extension if it is less than 512 bytes
    if(!tr.mode) carrier_ext();
    
    //Driving IPG
    for(int j = 0;j < tr.ipg_cnt; j++) begin  //8 bits wide * 12 clock = 96-bit times
      @(posedge v_intf.TX_CLK);
      v_intf.TXD   <= 0;
      v_intf.TX_EN <= 0;
      v_intf.TX_ER <= 0;      
    end
    frame_in_progress =0;  
  endtask    
    
  task send_jam_signal();
    for(int i = 0; i < 4;i++) begin //Sending 32-bit jam signal                 
      v_intf.TX_EN <= 1;      
      v_intf.TXD   <= 8'hFF; //Jam Pattern
      v_intf.TX_ER <= 0;    
      @(posedge v_intf.TX_CLK);
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
    if(!rand_slot)
      #(tr.ipg_cnt*8);
    frame_q = retry_q;
    drive_tx_frame(tr);
   
  endtask
    
  task frame_pack(ref eth_seq_item tr);
    idx = 0;
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
             `uvm_info("DRIVING DATA",
                    $sformatf("\n\t da=%h\n\t sa=%h\n\t type=%0h\n\t opcode=%0h\n\t priority_en_vector=%0d \n\t pfc_pause_time=%p 
										\n\t payload=%0d\n\t Frame size=%0d",tr.da, tr.sa, tr.ether_type, tr.pause_opc,tr.priority_en_vector,
										tr.pfc_pause_time, tr.payload.size(), idx), UVM_LOW) 
          end
          else begin // logic for pause frame
          frame_q[idx++] = tr.pause_time[15:8];
          frame_q[idx++] = tr.pause_time[7:0];
          for(int i = 0; i< 42;i++)
            frame_q[idx++] = 0;
          `uvm_info("DRIVING DATA", $sformatf("pause_frame_en=%0b,da=%p,sa=%p,type=%0h,opcode=%0h,payload=%0d,Frame size = %0d",tr.pause_frame_en,tr.da,tr.sa,tr.ether_type,tr.pause_opc,tr.payload.size(),idx),UVM_LOW)
	  end
	  end    
      else begin
        //Payload packing
        for(int i = (tr.payload.size()- 1);i >= 0 ;i--)
          frame_q[idx++] = tr.payload[i];
        //Zero Padding if payload is less than 46 bytes for normal frame and
	//42 bytes for vlan tagged frame
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
    
endclass

