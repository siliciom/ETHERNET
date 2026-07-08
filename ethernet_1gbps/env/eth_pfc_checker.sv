class eth_pfc_checker extends uvm_component;
  `uvm_component_utils(eth_pfc_checker);
  
  virtual eth_gmii_interface v_intf[`NO_OF_AGENTS];
  
  // ========== FRAME DATA ==========
  bit [7:0] frame_q[`NO_OF_AGENTS][$];
  int byte_cnt[`NO_OF_AGENTS];
  
  // ========== FRAME FIELDS ==========
  bit [15:0] opcode[`NO_OF_AGENTS];
  bit [15:0] ether_type[`NO_OF_AGENTS];
  bit [47:0] da[`NO_OF_AGENTS];
  bit [47:0] sa[`NO_OF_AGENTS];
  
  // ========== PFC SPECIFIC ==========
  bit [15:0] priority_vector[`NO_OF_AGENTS];
  bit [15:0] pfc_quanta[`NO_OF_AGENTS][8];
  
  // ========== PFC STATE ==========
  bit pfc_xoff_en[`NO_OF_AGENTS][8];
  bit pfc_override_en[`NO_OF_AGENTS][8];
  // ========== STATISTICS ==========
  int total_pfc_frames[`NO_OF_AGENTS];
  
  // ========== CONFIGURATION ==========
  bit [15:0] vlan_tpid;
  bit [15:0] vlan_tci;
  bit [2:0] vlan_pcp[`NO_OF_AGENTS];
  bit loop_brk[`NO_OF_AGENTS];
  bit loop_brk_p[`NO_OF_AGENTS][8];
  bit loop_brk_done[`NO_OF_AGENTS][8];
  bit zero_pause_time[`NO_OF_AGENTS][8];
  int clk[`NO_OF_AGENTS][8];
  int pause_time[`NO_OF_AGENTS][8];
  int byte_count[`NO_OF_AGENTS];
  int wait_for_pcp[`NO_OF_AGENTS];
  bit [2:0] tx_vlan_pcp[`NO_OF_AGENTS];
  int ipg_cnt[`NO_OF_AGENTS];
  int inn_ipg_cnt[`NO_OF_AGENTS][8];
  int no_of_pkts = 1000; 
  int actual_no_of_pkts[`NO_OF_AGENTS]; 

  function new(string name = "eth_pfc_checker", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
   
    if($value$plusargs("NO_OF_PKTS=%0d", no_of_pkts))
      `uvm_info(get_type_name(),$sformatf("NO_OF_PKTS from plusarg = %0d", no_of_pkts), UVM_DEBUG)
    else
      `uvm_info(get_type_name(), $sformatf("Using default NO_OF_PKTS = %0d", no_of_pkts),UVM_DEBUG)

    for(int i=0; i<`NO_OF_AGENTS; i++) begin
      if(!uvm_config_db#(virtual eth_gmii_interface)::get(this, "", $sformatf("vif_%0d",i), v_intf[i]))
        `uvm_fatal("PFC_CHK", $sformatf("Unable to get vif_%0d",i))
    end
  endfunction

  task run_phase(uvm_phase phase);
    wait(v_intf[0].rst);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      fork
        automatic int agent = i;
        sample_pfc_frame(agent);
        sample_transmitter(agent);
      join_none
    end
  endtask

  task sample_pfc_frame(int agent);
    int p;
    forever begin
      frame_q[agent].delete();
      byte_cnt[agent] = 0;
      priority_vector[agent] = 0;
      wait(v_intf[agent].RX_DV);
      while(v_intf[agent].RX_DV) begin
        @(posedge v_intf[agent].RX_CLK);
        frame_q[agent].push_back(v_intf[agent].RXD);
        if(byte_cnt[agent] < 7) begin  // Check preamble
          if(v_intf[agent].RXD != `PREAMBLE)
            `uvm_info("PFC_PREAMBLE_ERR", $sformatf("Agent=%0d Byte=%0d Expected=%02h Got=%02h", agent, byte_cnt[agent], `PREAMBLE,
	     v_intf[agent].RXD),UVM_DEBUG)
        end
        else if(byte_cnt[agent] == 7) begin  //SFD
          if(v_intf[agent].RXD != `SFD)
            `uvm_info("PFC_SFD_ERR", $sformatf("Agent=%0d Expected=%02h Got=%02h", agent, `SFD, v_intf[agent].RXD),UVM_DEBUG)
        end
        // Destination Address
        da[agent] = { frame_q[agent][8], frame_q[agent][9], frame_q[agent][10], frame_q[agent][11], frame_q[agent][12], frame_q[agent][13] };

        // Source Address
        sa[agent] = { frame_q[agent][14], frame_q[agent][15], frame_q[agent][16], frame_q[agent][17], frame_q[agent][18], frame_q[agent][19] };

        // EtherType
	if(byte_cnt[agent] == 25) begin
          ether_type[agent] = { frame_q[agent][20], frame_q[agent][21] };
          opcode[agent] = { frame_q[agent][22], frame_q[agent][23] };      // Opcode
          if(ether_type[agent] == 16'h8808 && opcode[agent] == 16'h0101) begin
            priority_vector[agent] = {frame_q[agent][24], frame_q[agent][25] };
            total_pfc_frames[agent]++;	    
	    `uvm_info("PFC_FRAME", $sformatf("Valid PFC Frame DA=%h SA=%h, priority_vector = %b",ether_type[agent],opcode[agent],priority_vector[agent]), UVM_DEBUG);
          end
	  else begin
            vlan_tpid = {frame_q[agent][20], frame_q[agent][21]};
            vlan_tci = { frame_q[agent][22], frame_q[agent][23] };
            vlan_pcp[agent] = vlan_tci[15:13];
	    loop_brk[agent] = 1;
	    break;
          end	  
	end
        byte_cnt[agent]++;
      end
      if(priority_vector[agent] != 0) begin
        wait(v_intf[agent].RX_DV == 0);
        for(p=0; p<8; p++) begin
          pfc_quanta[agent][p] = { frame_q[agent][26 + (p*2)], frame_q[agent][27 + (p*2)] };
          if(priority_vector[agent][p]) begin
            pfc_xoff_en[agent][p] = 1;
            if(pfc_xoff_en[agent][p] == 1 && clk[agent][p] != 0) begin
              pfc_override_en[agent][p] = 1;
              loop_brk_p[agent][p] = 1;
              wait(loop_brk_done[agent][p]);
              loop_brk_done[agent][p] = 0;
            end              
            fork //For pausing the particular pfc
      	      automatic int pr = p;
              check_pfc_pausing_time(agent,pr, pfc_quanta[agent][pr]);
            join_none
          end
        end
      end
      if(loop_brk[agent] == 1) begin
        wait(v_intf[agent].RX_DV == 0);
        loop_brk[agent] = 0;
      end      
    end
  endtask

  task check_pfc_pausing_time(int agent, int p, int p_time);
    p_time = p_time * 64;
    if(p_time == 0)
      zero_pause_time[agent][p] = 1;
    pause_time[agent][p] = p_time;
    forever begin
      if(v_intf[agent].TX_EN) begin
	if(byte_count[agent] > 22) begin
	  if(p == tx_vlan_pcp[agent]) begin
	    wait(v_intf[agent].TX_EN == 0);
            p_time--;
            clk[agent][p]++;
	  end
	end else begin
	  while(1) begin
	    @(posedge v_intf[agent].TX_CLK);
	    wait_for_pcp[agent]++;
	    if(byte_count[agent] > 22) break;
	  end
	  if(p == tx_vlan_pcp[agent]) begin
	    wait(v_intf[agent].TX_EN == 0);
	    wait_for_pcp[agent] = 0;
	  end
	end
	`uvm_info("", $sformatf("Agent - %0d, PFC Received with priority = %0d and pause time = %0d",agent,p,p_time), UVM_DEBUG)
      end
      if(wait_for_pcp[agent] != 0) begin
	p_time = p_time - 22;
	clk[agent][p] = 22;
	`uvm_info("WAIT_TIME_UPDATE", $sformatf("SINCE WAITED FOR PCP EXTRACTION, CURRENT PAUSE TIME = %0d", p_time), UVM_DEBUG)
	wait_for_pcp[agent] = 0;
      end

      while(p_time >= 0) begin
        @(posedge v_intf[agent].TX_CLK);
	 `uvm_info("",$sformatf("TIMER  %0d --clk = %0d,p = %0d p_time = %0d", agent,p, clk[agent][p],p_time),UVM_DEBUG)
        if(loop_brk_p[agent][p]) begin
          loop_brk_p[agent][p] = 0;
          loop_brk_done[agent][p] = 1;
	  `uvm_info("NON_PFC", $sformatf("Overriding happens Expected Cycles = %0d, Actual Cycles = %0d",
          pause_time[agent][p], clk[agent][p]), UVM_INFO)
          break;
        end        
	if(v_intf[agent].TX_EN && byte_count[agent] == 22) begin
	  if(v_intf[agent].TXD[7:5] == p) begin
	    `uvm_error("PFC_ERR", $sformatf( "Agent - %0d, Within pfc time expiration, the pause pfc of %0d is driving, Expected Cycles = %0d, Actual Cycles = %0d",
            agent, p,  pause_time[agent][p], clk[agent][p]-1))  
	  end
        end 
	if(!v_intf[agent].TX_EN) begin
	  inn_ipg_cnt[agent][p]++;
	end
	else
	  inn_ipg_cnt[agent][p] = 0;
	if(inn_ipg_cnt[agent][p] > 12 && ( no_of_pkts > (actual_no_of_pkts[agent]+1)) )
	  `uvm_error("TIMER_ERR", $sformatf( "Agent - %0d, TX_EN is low even after IPG Count",agent))  
        p_time--;
        clk[agent][p]++;
      end
      inn_ipg_cnt[agent][p] = 0;
      `uvm_info("PFC_FRAME", $sformatf("Agent - %0d, PCP = %0d, Expected Cycles = %0d, Actual Cycles = %0d", 
	        agent, p, pause_time[agent][p], clk[agent][p]-1), UVM_INFO);
      clk[agent][p] = 0;
      pfc_xoff_en[agent][p] = 0;
      break;
    end
    if(zero_pause_time[agent][p] != 0) begin
     while(1) begin
        @(posedge v_intf[agent].TX_CLK);
        if(ipg_cnt[agent][p] >= 11) begin
          if(!v_intf[agent].TX_EN) begin
            `uvm_error("EMPTY_CYCLES",$sformatf("Agent-%0d,Even though pfc timer completion, txd is still pausing in the time of %0t after 
	    completion of expected cycles of priority = %0d",agent, $time,p));
          end
	  else
            break;
        end
       	else if(v_intf[agent].TX_EN)
          break;
        ipg_cnt[agent][p]++;
      end
    end
    zero_pause_time[agent][p] = 0;
    ipg_cnt[agent][p] = 0;
  endtask

  task sample_transmitter(int i);

    forever begin
      wait(v_intf[i].TX_EN);
      actual_no_of_pkts[i]++;
      while(v_intf[i].TX_EN) begin
        @(posedge v_intf[i].TX_CLK);
	if(byte_count[i] == 22) begin
	  tx_vlan_pcp[i] = v_intf[i].TXD[7:5];
	end
        byte_count[i]++;
      end
      byte_count[i] = 0;
    end
  endtask
endclass


