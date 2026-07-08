class eth_pause_checker extends uvm_component;
  `uvm_component_utils(eth_pause_checker);
  virtual eth_gmii_interface v_intf[`NO_OF_AGENTS];
  eth_seq_item tr;
  bit [7:0] frame_q[`NO_OF_AGENTS][$];
  int byte_cnt[`NO_OF_AGENTS];
  int pause_override_cnt[`NO_OF_AGENTS];
  bit [15:0] opcode[`NO_OF_AGENTS];
  bit [15:0] ether_type[`NO_OF_AGENTS];
  bit loop_brk[`NO_OF_AGENTS];
  bit [48:0] da[`NO_OF_AGENTS];
  bit [48:0] sa[`NO_OF_AGENTS];
  bit pause_xoff_en[`NO_OF_AGENTS];
  bit start_pause_xoff_timing[`NO_OF_AGENTS];
  bit pause_xoff_start_en[`NO_OF_AGENTS];
  bit pause_override_en[`NO_OF_AGENTS];
  bit override_time_en[`NO_OF_AGENTS];
  int pause_agent[`NO_OF_AGENTS];
  bit [15:0] pause_time[`NO_OF_AGENTS];
  int clk[`NO_OF_AGENTS];
  int p_time[`NO_OF_AGENTS];
  bit pause_time_started[`NO_OF_AGENTS];

  function new(string name = "eth_pause_checker", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for(int i=0; i<`NO_OF_AGENTS; i++) begin
      if(!uvm_config_db#(virtual eth_gmii_interface)::get(this, "", $sformatf("vinf%0d",i), v_intf[i]))
        `uvm_fatal("PCH_CHK", $sformatf("Unable to get vif_%0d",i))
    end
  endfunction  

  task run_phase(uvm_phase phase);
    wait(v_intf[0].rst);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      fork
        automatic int agent = i;
        sample_pause_frame(agent);
        check_pausing_time(agent);
      join_none
    end    
  endtask

  task sample_pause_frame(int i);
    bit pause_entry[`NO_OF_AGENTS];
    forever begin
      wait(v_intf[i].RX_DV == 1)
      while(v_intf[i].RX_DV) begin
        @(negedge v_intf[i].RX_CLK);
        if(byte_cnt[i] < 7) begin  //Preamble Checking
          if(v_intf[i].RXD != `PREAMBLE) begin
	    `uvm_info("PCH_PREAMBLE_ERR", $sformatf( "Agent - %0d, Incorrect Preamble Received =%h",i, v_intf[i].RXD),UVM_DEBUG)	  
          end
        end
        else if(byte_cnt[i] == 7) begin //SFD Checking
          if(v_intf[i].RXD != `SFD) begin
	    `uvm_info("PCH_SFD_ERR", $sformatf( "Agent - %0d, Incorrect SFD Received =%h",i,v_intf[i].RXD),UVM_DEBUG)	  
          end
        end
        frame_q[i].push_back(v_intf[i].RXD);
        if(byte_cnt[i] == 23) begin  //Extracting fields upto opcode 
          opcode[i][7:0] = frame_q[i].pop_back();
          opcode[i][15:8] = frame_q[i].pop_back();
          ether_type[i][7:0] = frame_q[i].pop_back();
          ether_type[i][15:8] = frame_q[i].pop_back();
	  `uvm_info("PCH_OPC",$sformatf("Agent - %0d,Received Opcode = %h, Ethertype = %h",i,opcode[i],ether_type[i]),UVM_DEBUG)      

          if(opcode[i] == 16'h0001 && ether_type[i] == 16'h8808) begin //Condition for matching pause frame fields
            for(int j =0; j < 6;j++) 
              sa[i][j*8 +: 8] = frame_q[i].pop_back();

            for(int j =0; j < 6;j++)
              da[i][j*8 +: 8] = frame_q[i].pop_back();
	    `uvm_info("PCH_DA_SA",$sformatf("Agent - %0d,Received DA = %h, SA = %h --- xoff_en = %0d -- %0d -- %0d",
             i,da[i], sa[i],pause_xoff_en[i],p_time[i], clk[i]),UVM_INFO)      
	    frame_q[i].delete();
	    if(start_pause_xoff_timing[i]) begin //If pause is happening and need to overwrite the pause quanta
	      pause_override_en[i] = 1;
	    end
	    pause_xoff_en[i] = 1;
	    pause_entry[i] = 1;
          end
	  else begin //Avoiding the normal frame and reset the fields
            byte_cnt[i] = 0;
            opcode[i] = 0;
            ether_type[i] = 0;
            loop_brk[i] = 1;
            frame_q[i].delete();
            break;
          end
        end
        byte_cnt[i]++;
      end

      if(loop_brk[i]) begin //Break the loop if normal frame is detected
        wait(v_intf[i].RX_DV == 0) //Wait for disabling RX_DV to proceed with next frame
        loop_brk[i] = 0;
      end

      if((pause_xoff_en[i] || pause_override_en[i]) && pause_entry[i]) begin //If Pause frame is detected
	while(v_intf[i].RX_DV) begin //Push the fields from Pause Quanta to FCS
	  @(negedge v_intf[i].RX_CLK);
	  frame_q[i].push_back(v_intf[i].RXD);
	  byte_cnt[i]++;
	end
	if(byte_cnt[i] == 73) begin //Complete Pause Frame Length include Preamble and SFD
	  `uvm_info("PCH_RX_PAUSE",$sformatf("Agent - %0d,Received Pause with correct size",i),UVM_HIGH)      
	  pause_xoff_start_en[i] = 1;
	end
       	else
	  `uvm_error("PCH_INC_RX_PAUSE",$sformatf("Agent - %0d,Received Pause with incorrect size",i))      

        if(pause_override_en[i]) begin
          override_time_en[i] = 1;
	  pause_override_en[i] = 0;
        end
        if(pause_xoff_en[i]) begin
          start_pause_xoff_timing[i] = 1;
          pause_xoff_en[i] = 0;
        end
	pause_time[i][15:8] = frame_q[i].pop_front();
	pause_time[i][7:0] = frame_q[i].pop_front();
        byte_cnt[i] = 0;
        opcode[i] = 0;
        ether_type[i] = 0;
        loop_brk[i] = 0;
	pause_entry[i] = 0;
	`uvm_info("PCH_RX_PAUSE_TIME",$sformatf("Agent - %0d,Received Pause Quanta = %0d",i,pause_time[i]),UVM_HIGH)      
        frame_q[i].delete();
      end
    end
  endtask

  task check_pausing_time(int i);
    int prev_pause_time[`NO_OF_AGENTS];
    forever begin
      wait(v_intf[i].TX_EN == 0 && pause_xoff_start_en[i] == 1); //Start the loop once pause time is extracted(i.e, !byte_cnt - waiting for pause time)
      p_time[i] = pause_time[i];
      p_time[i] = p_time[i] * 64;
      while(p_time[i] >= 0) begin //Check the transmitter once the pause received until pause time completion
        @(posedge v_intf[i].TX_CLK);
	if(override_time_en[i] && start_pause_xoff_timing[i] == 1) begin //If Pause Override Happens during pause time
	  prev_pause_time[i] = pause_time[i];
	  p_time[i] = pause_time[i] * 64;
	  clk[i] = 1;
	  p_time[i]--;
	  `uvm_info("PCH_PAUSE_OVERWRITE",$sformatf("Agent - %0d,Due to overriding, updating the pause time -- %0d -- %0d",i,p_time[i], clk[i]),UVM_HIGH)      
          override_time_en[i] = 0;
	end

	if(v_intf[i].TX_EN == 0) begin
          clk[i]++;
	end
	else  begin
	  pause_override_cnt[i]++;
	end

	if(pause_override_cnt[i] >= 24 && pause_time[i] == prev_pause_time[i]) begin
	  `uvm_error("PCH_PAUSE_ERR0",$sformatf({"Agent - %0d, Overriding Within pause not happening, Data %h is driving in interface %0d\n",
	             "Expected cycles = %0d, Actual Cycles Completed= %0d"},i,v_intf[i].TXD,i, (pause_time[i]*64), clk[i]))
	end
       	else if( pause_override_cnt[i] > 0 && v_intf[i].TX_EN != 0) begin
	  `uvm_error("PCH_PAUSE_ERR1",$sformatf({"Agent - %0d,Within pause timer expiration, Data %h is driving in interface %0d\n",
	             "Expected cycles = %0d, Actual Cycles Completed= %0d"},i,v_intf[i].TXD,i, (pause_time[i]*64), clk[i]))
	end

	pause_time_started[i] = 1;
        p_time[i]--;
      end
      `uvm_info("PCH_DATA",$sformatf({"Agent - %0d,Expected cycles = %0d, Actual Cycles Completed= %0d"},i, int'(pause_time[i])*64, clk[i]-1), UVM_HIGH) 
      pause_xoff_start_en[i] = 0;
      start_pause_xoff_timing[i] = 0;
      pause_time[i] = 0;
      clk[i] = 0;
      p_time[i] = 0;
      pause_override_cnt[i] = 0;
    end
  endtask
endclass


