class eth_mon extends uvm_monitor;
  `uvm_component_utils(eth_mon)

  uvm_analysis_port #(eth_seq_item) tx_ap;
  uvm_analysis_port #(eth_seq_item) rx_ap;
  virtual eth_gmii_interface v_intf;
  bit [47:0] mac_addr;
  bit multi_mac_addr[bit [47:0]];
  int rx_pkt_count;
  int tx_pkt_count;
  bit [7:0] tx_frame_q[$];
  bit [7:0] rx_frame_q[$];
  bit half_duplex;
  bit frame_transmission;
  bit throughput_switch; 
  longint  tx_total_bytes;
  time     tx_start_time;
  int      tx_frame_bytes;
  time     tx_end_time;
  bit      tx_first_pkt;
  time     tx_frame_start_time;
  longint  rx_total_bytes;
  time     rx_start_time;
  int      rx_frame_bytes;
  time     rx_end_time;
  bit      rx_first_pkt;
  time     rx_frame_start_time;
  realtime tx_throughput_mbps;
  realtime rx_throughput_mbps;
  // Payload bytes
  longint tx_payload_bytes;
  longint rx_payload_bytes;
 
  // Line bytes (Frame + Preamble + SFD + IFG)
  longint tx_line_bytes;
  longint rx_line_bytes;
  // Throughputs
  realtime tx_payload_throughput_mbps;
  realtime rx_payload_throughput_mbps;
  realtime tx_line_throughput_mbps;
  realtime rx_line_throughput_mbps;

  function new(string name="eth_mon", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  // BUILD
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);
    if(!uvm_config_db #(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal("MON","VIF CONNECTION FAILED")
    if($test$plusargs("THROUGHPUT"))
      throughput_switch = 1;
  endfunction

  // RUN                                                        
  task run_phase(uvm_phase phase);
    wait(v_intf.rst);
    fork
      tx_mon();
      rx_mon();
    join_none
  endtask

  // TX MONITOR
  task tx_mon();
    eth_seq_item tr;
    bit crc_ok;
    bit da_match;
    bit collision_seen;
    int byte_cnt;
    bit [47:0] tx_da;
    int tx_ipg_violation_count;
    bit invalid_ethertype_tx;
    bit bad_sfd_tx;
    bit bad_preamble_tx;
    bit tx_er_seen;
    bit len_mismatch_tx;
    bit tx_late_collision;
    bit carrier_ext_seen;
    int carrier_ext_cnt;
    bit pkt_bad;
    int min_payload;
    tx_ipg_violation_count=`IPG_COUNT;
    forever begin
      if(!v_intf.mon_cb.TX_EN) begin
        tx_ipg_violation_count += 8;
        @(v_intf.mon_cb);
      end
      tx_frame_q.delete();
      collision_seen       = 0;
      crc_ok               = 0;
      da_match             = 0;
      byte_cnt             = 0;
      invalid_ethertype_tx = 0;
      tx_late_collision    = 0;
      bad_preamble_tx      = 0;
      bad_sfd_tx 	   = 0;
      tx_er_seen           = 0;
      len_mismatch_tx      = 0;
      pkt_bad              = 0;
      carrier_ext_seen     = 0;

      if(v_intf.mon_cb.TX_EN) begin
	tx_frame_start_time = $time;
       	if(tx_ipg_violation_count < `IPG_COUNT) begin
          statistics::tx_ipg_violation_pending[mac_addr]++;
	  `uvm_error("TX_IPG_VIOLATION",$sformatf("IFG violation detected IFG=%0d bit-times",tx_ipg_violation_count))
	end
	tx_ipg_violation_count = 0;
	//DETECTNG COLLISION
	while(v_intf.mon_cb.TX_EN) begin
	  if(v_intf.mon_cb.COL) begin
	    collision_seen=1;
	    if(byte_cnt > 64)
	      tx_late_collision =1;
	  end
          // TX_ER
          if(v_intf.mon_cb.TX_ER) begin
            pkt_bad   = 1;
            tx_er_seen = 1;
          end
          // PREAMBLE CHECK
          if(byte_cnt < 7) begin
            if(v_intf.mon_cb.TXD != `PREAMBLE) begin
              pkt_bad = 1;
              bad_preamble_tx = 1;
            end
          end
          // SFD CHECK
          else if(byte_cnt == 7) begin
            if(v_intf.mon_cb.TXD != `SFD) begin
              pkt_bad = 1;
              bad_sfd_tx = 1;
            end
          end
          // STORE ONLY DA ONWARDS
          tx_frame_q.push_back(v_intf.mon_cb.TXD);
          byte_cnt++;
          @(v_intf.mon_cb);
        end
        while(v_intf.mon_cb.TXD == 8'h0F) begin
          carrier_ext_seen = 1;
          carrier_ext_cnt++;
          //addr_classify_tx(tr);
          @(v_intf.mon_cb);
        end
	tx_frame_bytes = tx_frame_q.size();
	if(throughput_switch) begin	
          if(!tx_first_pkt) begin
            tx_first_pkt  = 1;
            tx_start_time = tx_frame_start_time;   
          end
          tx_total_bytes += tx_frame_bytes;
          tx_end_time = $time;
        end          
        if(carrier_ext_seen) begin
          `uvm_info("TX_CARRIER_EXT",$sformatf("Carrier extension bytes=%0d",carrier_ext_cnt),UVM_HIGH)
        end  
        // CREATE TR
        tr = eth_seq_item::type_id::create("tr", this);
        if(!collision_seen || tx_late_collision) tx_pkt_count++;
        tr.tx_count=tx_pkt_count;
        // DA EXTRACTION
        tx_da = {
        tx_frame_q[8],
        tx_frame_q[9],
        tx_frame_q[10],
        tx_frame_q[11],
        tx_frame_q[12],
        tx_frame_q[13]
        };

        // DA MATCH
        foreach(tr.mac_addr[i]) begin
          if(tx_da == tr.mac_addr[i]) begin
            da_match = 1;
            break;
          end
        end

        if(tx_da == 48'hFF_FF_FF_FF_FF_FF)
          da_match = 1;
        
        foreach(tr.multi_mac_addr[i]) begin
	  if(mac_addr!=tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tx_da))
	    da_match = 1;
        end
        if(tx_late_collision) begin
	        statistics::tx_collision_pending[mac_addr]++;
          `uvm_info("TX_LATE_COLLISION",$sformatf("late collision detected byte_cnt=%0d",byte_cnt),UVM_HIGH)	  
        end
        else if(collision_seen) begin
          statistics::tx_collision_pending[mac_addr]++;
	  half_duplex = 1;
          `uvm_info("TX_COLLISION_DETECTED",$sformatf("Collision detected frame_size=%0d",tx_frame_q.size()),UVM_HIGH)
          continue;
        end
        if(carrier_ext_seen) begin
          statistics::tx_carrier_ext_pending[mac_addr]++; 
          `uvm_info("TX_CARRIER_EXT_SUMMARY",$sformatf( "Carrier extension bytes=%0d",carrier_ext_cnt),UVM_HIGH)
        end
        // UNPACK
        crc_ok = frame_unpack(tr, tx_frame_q, 8, 0, len_mismatch_tx, invalid_ethertype_tx);
	if(throughput_switch) begin
	  tx_payload_bytes += tr.payload.size();  // payload bytes
          tx_line_bytes += (tx_frame_bytes + 12);
        end
        if(tr.vlan_en) begin
          if(tr.TPID != 16'h8100) begin
            `uvm_error("VLAN_TPID", $sformatf( "Invalid TPID = %h", tr.TPID))
          end
        end
        if(!da_match)
          pkt_bad = 1;

        if(invalid_ethertype_tx)
          pkt_bad = 1;

        // Length mismatch
        if(len_mismatch_tx && tr.payload.size() >= 46)
          pkt_bad = 1;

        // CRC
        if(!crc_ok)
          pkt_bad = 1;

        // ERROR PRINTS
        if(tx_er_seen) begin
          `uvm_error("TX_ERR", $sformatf( "TX_ER asserted frame_size=%0d", tx_frame_q.size()))
        end
        if(bad_preamble_tx) begin
          `uvm_error("TX_PREAMBLE_ERR", $sformatf( "Bad Preamble frame_size=%0d", tx_frame_q.size()))
        end
        if(bad_sfd_tx) begin
          `uvm_error("TX_SFD_ERR", $sformatf( "Bad SFD frame_size=%0d", tx_frame_q.size()))
        end
        if(!da_match) begin
          `uvm_error("TX_INVALID_DA", $sformatf( "Invalid DA=%h", tx_da))
        end
        if(invalid_ethertype_tx) begin
          `uvm_error("TX_UNDEFINED_ETHERTYPE", $sformatf( "Undefined EtherType=%0d", tr.ether_type))
        end
        if(len_mismatch_tx && tr.payload.size()>=46) begin
          `uvm_error("TX_LEN_DATA_MISMATCH", $sformatf( "Length mismatch detected"))
        end
        if(!crc_ok && tr.payload.size()>=46) begin
          `uvm_error("TX_CRC_ERR", $sformatf( "Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
        end
        if(!crc_ok && tr.payload.size()<46) begin
          `uvm_error("TX_FRAGMENT_CRC", $sformatf( "Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
        end
        addr_classify_tx(tr);
        
	// VLAN
        if(tr.vlan_en)
           statistics::tx_vlan_pending[mac_addr]++;
        
	// RUNT / FRAGMENT
        min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : `MIN_PAYLOAD_SIZE;
        if(tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin		
          if(crc_ok) begin
            statistics::tx_runt_pending[mac_addr]++;
            `uvm_info("TX_RUNT_PKT", $sformatf( "Good runt packet payload=%0d", tr.payload.size()), UVM_HIGH)
            pkt_bad=1;
          end
          else begin
            statistics::tx_fragment_pending[mac_addr]++;
            pkt_bad = 1;
            `uvm_error("TX_FRAGMENT_PKT",$sformatf("Fragment detected payload=%0d",tr.payload.size()))
          end
        end    

  `ifdef JUMBO_EN
        if(tr.payload.size()>=1536 && tr.payload.size()<16383) begin
          if(crc_ok) begin
            statistics::tx_jumbo_pending[mac_addr]++;
            `uvm_info("TX_JUMBO_PKT",$sformatf("Jumbo detected payload=%0d",tr.payload.size()),UVM_HIGH)
          end
        end
  `else
        if(tr.payload.size() >= 1536) begin
          if(crc_ok) begin
  	    pkt_bad=1;
            `uvm_error("TX_LONG_PKT", $sformatf( "Long packet payload=%0d", tr.payload.size()))
          end
          else begin
            statistics::tx_jabber_pending[mac_addr]++;
            `uvm_error("TX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))
  	    pkt_bad=1;
          end
        end
  `endif

        // BLOCK PAUSE TO SCOREBOARD
        if(tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin 
          if(tx_frame_q.size()<64) begin
            `uvm_error("Short Pause_pkt",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d", 
	           tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.payload.size()))
            statistics::tx_bad_pkt_pending[mac_addr]++;     
	  continue;
	  end
	  else begin
            statistics::tx_good_pkt_pending[mac_addr]++;
            if(tr.pause_time == 0)
              statistics::tx_pause_xon_pending[mac_addr]++;
            else
     	      statistics::tx_pause_xoff_pending[mac_addr]++;
            `uvm_info("TX_PAUSE_BLOCK",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d", 
	       tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.pause_time),UVM_HIGH)
    	    continue;
          end
        end
        else if(tr.pfc_frame_en && tr.pause_opc == 16'h0101 && tr.ether_type == 16'h8808) begin
          if(tx_frame_q.size()<64) begin
            `uvm_error("Short Pfc_pkt",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d", 
	    tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.payload.size()))
            statistics::tx_bad_pkt_pending[mac_addr]++;     
	    continue;
	  end
	  else begin
            statistics::tx_good_pkt_pending[mac_addr]++;
	    for(int i=0;i<8;i++) begin
              if(tr.priority_en_vector[i]) begin
                if(tr.pfc_pause_time[i] == 0) begin
                  statistics::tx_pfc_xon_pending[mac_addr]++;
                  case(i)
                    0: statistics::tx_pfc_xon_prio0_pending[mac_addr]++;
                    1: statistics::tx_pfc_xon_prio1_pending[mac_addr]++;
                    2: statistics::tx_pfc_xon_prio2_pending[mac_addr]++;
                    3: statistics::tx_pfc_xon_prio3_pending[mac_addr]++;
                    4: statistics::tx_pfc_xon_prio4_pending[mac_addr]++;
                    5: statistics::tx_pfc_xon_prio5_pending[mac_addr]++;
                    6: statistics::tx_pfc_xon_prio6_pending[mac_addr]++;
                    7: statistics::tx_pfc_xon_prio7_pending[mac_addr]++;
                  endcase
                end
                else begin
                  statistics::tx_pfc_xoff_pending[mac_addr]++;
                  case(i)
                    0: statistics::tx_pfc_xoff_prio0_pending[mac_addr]++;
                    1: statistics::tx_pfc_xoff_prio1_pending[mac_addr]++;
                    2: statistics::tx_pfc_xoff_prio2_pending[mac_addr]++;
                    3: statistics::tx_pfc_xoff_prio3_pending[mac_addr]++;
                    4: statistics::tx_pfc_xoff_prio4_pending[mac_addr]++;
                    5: statistics::tx_pfc_xoff_prio5_pending[mac_addr]++;
                    6: statistics::tx_pfc_xoff_prio6_pending[mac_addr]++;
                    7: statistics::tx_pfc_xoff_prio7_pending[mac_addr]++;
                  endcase   
                end
              end
            end
	  end
          `uvm_info("TX_PFC_BLOCK","PFC frame blocked from scoreboard",UVM_HIGH)
          continue;
        end
        else if(tr.ether_type == 16'h8808 && tr.pause_opc != 16'h0001 && tr.pause_opc != 16'h0101) begin
          statistics::tx_control_pkt_pending[mac_addr]++;
          `uvm_info("TX_CONTROL",$sformatf("Unknown control packet opcode=%h sent to scoreboard",tr.pause_opc),UVM_HIGH)
        end
        else begin
          `uvm_info("TX_NORMAL_PKT","TX packet",UVM_HIGH)
        end    
    	if(pkt_bad)
     	  tr.err_b=1;
     	if(pkt_bad) begin
     	  statistics::tx_bad_pkt_pending[mac_addr]++;
     	end
        else begin
	  statistics::tx_good_pkt_pending[mac_addr]++;
	end
	tx_ap.write(tr);
      end
    end
  endtask 

  // RX MONITOR
  task rx_mon();
    eth_seq_item tr;
    bit bad_pkt;
    bit crc_ok;
    bit da_match;
    int min_payload;
    int byte_cnt;
    bit [47:0] rx_da;
    bit invalid_ethertype;
    int rx_ipg_violation_count;
    bit bad_preamble;
    bit bad_sfd;
    bit rx_er_seen;
    bit collision_seen_rx;
    bit rx_late_collision;
    time last_pause_rx_time;
    bit [15:0] active_pause_time;
    bit len_mismatch_rx;
    bit rx_carrier_ext_seen;
    int rx_carrier_ext_count;
    rx_ipg_violation_count=`IPG_COUNT;
    rx_carrier_ext_seen  = 0;
    rx_carrier_ext_count = 0;

    forever begin
      collision_seen_rx   = 0;
      bad_pkt             = 0;
      byte_cnt            = 0;
      len_mismatch_rx     = 0;
      bad_preamble        = 0;
      bad_sfd             = 0;
      rx_er_seen          = 0;
      invalid_ethertype   = 0;
      rx_carrier_ext_seen = 0;
      rx_frame_q.delete();      
      while(!v_intf.mon_cb.RX_DV)begin
       	rx_ipg_violation_count += 8;
       	@(v_intf.mon_cb);
      end

      if(v_intf.mon_cb.RX_DV) begin
	rx_frame_start_time = $time;
       	if(rx_ipg_violation_count < `IPG_COUNT) begin
	  statistics::rx_ipg_violation_pending[mac_addr]++;
	  `uvm_error("RX_IPG_VIOLATION",$sformatf("IFG violation detected IFG=%0d bit-times",rx_ipg_violation_count))
        end
        rx_ipg_violation_count=0;
        while(v_intf.mon_cb.RX_DV) begin
          if(v_intf.mon_cb.RX_ER) begin
            if(!bad_pkt)
              bad_pkt = 1;
            rx_er_seen = 1;
          end
          if(byte_cnt < 7) begin
            if(v_intf.mon_cb.RXD != `PREAMBLE) begin
              if(!bad_pkt)
                bad_pkt = 1;
              bad_preamble = 1;
            end
          end
          else if(byte_cnt == 7) begin
            if(v_intf.mon_cb.RXD != `SFD) begin
              if(!bad_pkt)
                bad_pkt = 1;
              bad_sfd = 1;
            end
          end      
          else begin
            rx_frame_q.push_back(v_intf.mon_cb.RXD);
          end
          byte_cnt++;
	  frame_transmission = 1;
          @(v_intf.mon_cb);
        end
	if(throughput_switch) begin
	  rx_frame_bytes = rx_frame_q.size() + 8 ;
          `uvm_info("RX_FRAME",$sformatf("RX_FRAME[%0d] bytes=%0d time=%0t", rx_pkt_count, rx_frame_bytes, $time),UVM_HIGH);
          if(!rx_first_pkt) begin
            rx_first_pkt  = 1;
            rx_start_time = rx_frame_start_time + 8;   
          end
          rx_total_bytes += rx_frame_bytes;
          rx_end_time = $time;
	  $display("RX_end_pkt %0t", rx_end_time);
        end

        // Carrier extension handling
        while(v_intf.mon_cb.RXD == 8'h0F) begin
	  rx_carrier_ext_seen = 1;
	  rx_carrier_ext_count++;
	  @(v_intf.mon_cb);
        end
        if(rx_carrier_ext_seen) begin
	  statistics::rx_carrier_ext_pending[mac_addr]++;
	  half_duplex = 1;
	  `uvm_info("RX_CARRIER_EXT",$sformatf("Carrier extension bytes=%0d",rx_carrier_ext_count),UVM_HIGH)
        end
        if(v_intf.mon_cb.COL) begin
          collision_seen_rx=1;
	  if(byte_cnt>64)
	    rx_late_collision = 1;
        end
        // create transaction
        tr = eth_seq_item::type_id::create("tr", this);
        if(!v_intf.mon_cb.COL || rx_late_collision)
          rx_pkt_count++;
        tr.rx_count=rx_pkt_count;
        tr.agt_addr=mac_addr;
        // DA extraction
        rx_da = {
        rx_frame_q[0],
        rx_frame_q[1],
        rx_frame_q[2],
        rx_frame_q[3],
        rx_frame_q[4],
        rx_frame_q[5]
        }; 

        // DA validation
        da_match = 0;

        if(rx_da == mac_addr)
	  da_match = 1;

        if(rx_da == 48'hFF_FF_FF_FF_FF_FF)
	  da_match = 1;

        if(multi_mac_addr.exists(rx_da))
          da_match = 1;

        // COLLISION
        if(collision_seen_rx && !rx_late_collision) begin
	  half_duplex = 1;
          `uvm_info("RX_COLLISION",$sformatf("Collision detected frame_size=%0d",rx_frame_q.size()),UVM_HIGH)
           continue;
        end
        // bad preamble / sfd / rx_er
        if(bad_pkt) begin
          addr_classify_rx(tr);
          if(rx_er_seen) begin
            `uvm_error("RX_ERR", $sformatf( "RX_ER asserted : Dropping packet frame_size=%0d", rx_frame_q.size()))	  
          end
          if(bad_preamble) begin
            `uvm_error("RX_PREAMBLE_ERR", $sformatf( "Bad Preamble detected : Dropping packet frame_size=%0d", rx_frame_q.size()))	  
          end
          if(bad_sfd) begin
            `uvm_error("RX_SFD_ERR", $sformatf( "Bad SFD detected : Dropping packet frame_size=%0d", rx_frame_q.size()))	  
          end    
          statistics::rx_bad_pkt_pending[mac_addr]++;
          continue;
        end
        // Invalid DA
        if(!da_match) begin
          statistics::rx_bad_pkt_pending[mac_addr]++;
	  addr_classify_rx(tr);
          `uvm_error("RX_INVALID_DA", $sformatf("Invalid DA = %h", rx_da))
          continue;
        end
	// Frame Unpack
        crc_ok = frame_unpack(tr, rx_frame_q, 0, 1, len_mismatch_rx,invalid_ethertype);

	if(throughput_switch) begin
	  rx_payload_bytes += tr.payload.size();    // Payload bytes
          rx_line_bytes += (rx_frame_bytes + 12);  // Line bytes = Frame + Preamble/SFD + IFG
        end
        frame_transmission = 0;
        if(invalid_ethertype) begin
          addr_classify_rx(tr);
          statistics::rx_bad_pkt_pending[mac_addr]++;
          `uvm_error("RX_UNDEFINED_ETHERTYPE", $sformatf( "Dropping packet : Undefined EtherType = %0d", tr.ether_type))
          continue;
        end
        if(len_mismatch_rx && tr.payload.size() >= 46) begin
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          `uvm_error("RX_LEN_DATA_MISMATCH", $sformatf( "Length mismatch DA=%h SA=%h payload=%0d", tr.da, tr.sa, tr.payload.size()))
          continue;
        end	
        if(tr.vlan_en) begin
          statistics::rx_vlan_pending[mac_addr]++; 
          if(tr.TPID != 16'h8100) begin
	    `uvm_error("VLAN_TPID", $sformatf( "Invalid TPID = %h", tr.TPID))
          end
        end
        // RUNT / FRAGMENT
        min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : `MIN_PAYLOAD_SIZE;
        if(tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin
          if(crc_ok) begin
            addr_classify_rx(tr);
            statistics::rx_runt_pending[mac_addr]++;
            statistics::rx_bad_pkt_pending[mac_addr]++;
            `uvm_info("RX_RUNT_PKT", $sformatf( "Good runt packet payload=%0d", tr.payload.size()), UVM_HIGH)
             continue;
          end
          else if(!collision_seen_rx) begin
            addr_classify_rx(tr);
            statistics::rx_fragment_pending[mac_addr]++;
            statistics::rx_bad_pkt_pending[mac_addr]++;
            `uvm_error("RX_FRAGMENT_PKT", $sformatf( "Fragment detected payload=%0d", tr.payload.size()))
            continue;
          end
        end

  `ifdef JUMBO_EN
        if(tr.payload.size()>=1536 && tr.payload.size()<16383) begin
          if(crc_ok) begin
            statistics::rx_jumbo_pending[mac_addr]++;
            `uvm_info("RX_JUMBO_PKT",$sformatf("Jumbo detected payload=%0d",tr.payload.size()),UVM_HIGH)
          end
         end
  `else
	if(tr.payload.size() >= 1536) begin
          if(crc_ok) begin
            bad_pkt = 1;
            statistics::rx_bad_pkt_pending[mac_addr]++;
            addr_classify_rx(tr);
            `uvm_error("RX_LONG_PKT", $sformatf( "Long packet payload=%0d", tr.payload.size()))
	    continue;
          end
          else begin
            statistics::rx_jabber_pending[mac_addr]++;
            `uvm_error("RX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))

          end
        end
  `endif
        if(!crc_ok) begin
          addr_classify_rx(tr);
          statistics::rx_bad_pkt_pending[mac_addr]++;
          `uvm_error("RX_CRC_DROP",$sformatf("Dropping packet : Bad FCS DA=%h SA=%h CRC=%h",tr.da, tr.sa, tr.crc))
          continue;
        end
        // PAUSE FRAME
        if(tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin
	  if(rx_frame_q.size()<64) begin
            `uvm_error("Short Pause_pkt",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d", 
	    tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.payload.size()))
            statistics::tx_bad_pkt_pending[mac_addr]++;     
	    continue;
          end
	  else begin
            statistics::pause_value[mac_addr]  = tr.pause_time;
            statistics::pause_flag[mac_addr]   = 1;
            statistics::pause_update[mac_addr] = 1;
            statistics::rx_good_pkt_pending[mac_addr]++;
            addr_classify_rx(tr);
            if(tr.pause_time == 0)
              statistics::rx_pause_xon_pending[mac_addr]++;
            else
              statistics::rx_pause_xoff_pending[mac_addr]++; 
    	    `uvm_info("RX_PAUSE_BLOCK",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d", 
	    tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.pause_time),UVM_HIGH)
     	    continue;
          end
        end
        // PFC FRAME
        else if(tr.pfc_frame_en && tr.pause_opc == 16'h0101 && tr.ether_type == 16'h8808) begin
	  if(rx_frame_q.size()<64) begin
            `uvm_error("Short Pfc_pkt",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d", 
	    tr.pfc_frame_en,tr.ether_type,tr.pause_opc,tr.payload.size()))
            statistics::tx_bad_pkt_pending[mac_addr]++;     
	    continue;
	  end
	  else begin
            statistics::rx_good_pkt_pending[mac_addr]++;	
            addr_classify_rx(tr);
            for(int i=0;i<8;i++) begin
              if(tr.priority_en_vector[i]) begin
                statistics::pfc_value[mac_addr][i] = tr.pfc_pause_time[i];
                statistics::pfc_flag[mac_addr][i] = 1;
                statistics::pfc_update[mac_addr][i]=1;
                if(tr.pfc_pause_time[i] == 0) begin
	          statistics::rx_pfc_xon_pending[mac_addr]++;		
                  case(i)
                    0: statistics::rx_pfc_xon_prio0_pending[mac_addr]++;
                    1: statistics::rx_pfc_xon_prio1_pending[mac_addr]++;
                    2: statistics::rx_pfc_xon_prio2_pending[mac_addr]++;
                    3: statistics::rx_pfc_xon_prio3_pending[mac_addr]++;
                    4: statistics::rx_pfc_xon_prio4_pending[mac_addr]++;
                    5: statistics::rx_pfc_xon_prio5_pending[mac_addr]++;
                    6: statistics::rx_pfc_xon_prio6_pending[mac_addr]++;
                    7: statistics::rx_pfc_xon_prio7_pending[mac_addr]++;
                  endcase
                end
                else begin
	          statistics::rx_pfc_xoff_pending[mac_addr]++;		
                  case(i)
                    0: statistics::rx_pfc_xoff_prio0_pending[mac_addr]++;
                    1: statistics::rx_pfc_xoff_prio1_pending[mac_addr]++;
                    2: statistics::rx_pfc_xoff_prio2_pending[mac_addr]++;
                    3: statistics::rx_pfc_xoff_prio3_pending[mac_addr]++;
                    4: statistics::rx_pfc_xoff_prio4_pending[mac_addr]++;
                    5: statistics::rx_pfc_xoff_prio5_pending[mac_addr]++;
                    6: statistics::rx_pfc_xoff_prio6_pending[mac_addr]++;
                    7: statistics::rx_pfc_xoff_prio7_pending[mac_addr]++;
                  endcase
                end
                `uvm_info("MON_PFFFFC",$sformatf("pfc_flag[%h][%h]=%d",mac_addr,i,statistics::pfc_flag[mac_addr][i]),UVM_HIGH)
              end
            end
          end
          `uvm_info("RX_PFC_BLOCK","PFC frame blocked from scoreboard",UVM_HIGH)
          continue;
        end
        else if(tr.ether_type == 16'h8808 && tr.pause_opc != 16'h0001 && tr.pause_opc != 16'h0101) begin
          statistics::rx_control_pkt_pending[mac_addr]++;
          `uvm_info("RX_CONTROL",$sformatf("Unknown control packet opcode=%h sent to scoreboard",tr.pause_opc),UVM_HIGH)
        end
        else begin
          `uvm_info("RX_NORMAL_PKT","RX packet",UVM_HIGH)
        end    
        if(rx_late_collision) 
          `uvm_info("RX_LATE_COLLISION",$sformatf("late collision detected byte_cnt=%0d",byte_cnt),UVM_HIGH)	  
        if(!bad_pkt && crc_ok) begin
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
        end
        //addr_classify_rx(tr);
	if(half_duplex)
	  tr.mode = 0;
	else
	  tr.mode = 1;
        fork
          if(half_duplex) #20 rx_ap.write(tr);
          else #0 rx_ap.write(tr);
        join_none
      end
    end
  endtask

  task addr_classify_rx(eth_seq_item tr);
    if(tr.da == 48'hFF_FF_FF_FF_FF_FF)
      statistics::rx_broadcast_pending[mac_addr]++;
    else if(multi_mac_addr.exists(tr.da) && !tr.pause_frame_en && !tr.pfc_frame_en)
      statistics::rx_multicast_pending[mac_addr]++;
    else
      statistics::rx_unicast_pending[mac_addr]++;
  endtask

  task addr_classify_tx(eth_seq_item tr);
    if(tr.da == 48'hFF_FF_FF_FF_FF_FF)
      statistics::tx_broadcast_pending[mac_addr]++;
    else if (tr.da[40] && !tr.pause_frame_en && !tr.pfc_frame_en) begin
      foreach(tr.multi_mac_addr[i]) begin
	if(mac_addr!=tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tr.da)) begin
	  statistics::tx_multicast_pending[mac_addr]++;
	  break;
	end
      end
    end
    else
      statistics::tx_unicast_pending[mac_addr]++;
  endtask

  //------------------------------------------------------------
  // FRAME UNPACK
  //------------------------------------------------------------
  function bit frame_unpack(
    eth_seq_item  tr,
    ref bit [7:0] frame_q[$],
    input int     offset,
    input bit     residue_mode,
    output bit len_mismatch,
    output bit  invalid_ethertype
    );

    int idx = offset;
    bit [31:0] next_crc;
    int payload_size;
    int actual_payload_size;
    int min_payload;
    len_mismatch = 0;
    invalid_ethertype=0;

    if(residue_mode == 0) begin
      for(int i=0;i<7;i++) begin // Extracting preamble field from the memory
        tr.preamble[i] = frame_q[i];
      end
      tr.sfd = frame_q[7]; // Extracting sfd
    end
    // DA extraction
    for(int i = 5; i >= 0; i--)
      tr.da[i*8 +: 8] = frame_q[idx++];
    // SA extraction
    for(int i = 5; i >= 0; i--)
      tr.sa[i*8 +: 8] = frame_q[idx++];
    // VLAN extraction
    if({frame_q[idx], frame_q[idx+1]} == 16'h8100) begin
      tr.vlan_en   = 1;
      tr.TPID      = {frame_q[idx], frame_q[idx+1]};
      idx         += 2;
      tr.PCP       = frame_q[idx][7:5];
      tr.DEI       = frame_q[idx][4];
      tr.VID[11:8] = frame_q[idx][3:0];
      idx++;
      tr.VID[7:0]  = frame_q[idx];
      idx++;
    end
    else
      tr.vlan_en = 0;
      // EtherType / Length
    tr.ether_type[15:8] = frame_q[idx++];
    tr.ether_type[7:0]  = frame_q[idx++];

      // Pause frame extraction
    if(tr.ether_type == 16'h8808) begin
      tr.pause_opc = {frame_q[idx], frame_q[idx+1]};
      idx += 2;
      if(tr.pause_opc == 16'h0001) begin
        tr.pause_frame_en = 1;
        tr.pfc_frame_en   = 0;
        tr.pause_time = {frame_q[idx], frame_q[idx+1]};
        idx += 2;
        tr.payload = new[`PAUSE_PAYLOAD_SIZE];
        for(int i=0;i<`PAUSE_PAYLOAD_SIZE;i++)
        tr.payload[i] = frame_q[idx++];
      end
      else if(tr.pause_opc == 16'h0101) begin
        tr.pause_frame_en = 0;
        tr.pfc_frame_en   = 1;
        tr.priority_en_vector = {frame_q[idx], frame_q[idx+1]};
        idx += 2;
        for(int i=0;i<8;i++) begin
          tr.pfc_pause_time[i] = {frame_q[idx], frame_q[idx+1]};
          idx += 2;
        end
        // reserved bytes
        tr.payload = new[`PFC_PAYLOAD_SIZE];
        for(int i=0;i<`PFC_PAYLOAD_SIZE;i++)
          tr.payload[i] = frame_q[idx++];
      end
    end
    // Actual bytes on wire = total queue - bytes consumed so far - 4 (CRC)
    actual_payload_size = int'(frame_q.size() - idx - 4);
    // LENGTH FIELD
    if(tr.ether_type <= 16'd1500 && !tr.pause_frame_en && !tr.pfc_frame_en) begin
      payload_size = int'(tr.ether_type);
      if(tr.vlan_en)
        min_payload = `VLAN_PAYLOAD_SIZE;
      else
        min_payload = `MIN_PAYLOAD_SIZE;
      `uvm_info("MON_LEN_CHECK", $sformatf( "ether_type(claimed)=%0d actual_payload=%0d", payload_size, actual_payload_size), UVM_HIGH)
      // PAYLOAD < MIN PAYLOAD
      if(payload_size < min_payload) begin
        if(actual_payload_size != min_payload) begin
          len_mismatch = 1;
          `uvm_error("MON_PADDING_ERROR", $sformatf( "Wrong padding length=%0d actual=%0d expected=%0d", payload_size, actual_payload_size, min_payload))
          end
        end
        else begin
          if(payload_size != actual_payload_size) begin
            len_mismatch = 1;
          `uvm_error("MON_LEN_MISMATCH", $sformatf( "DA=%h SA=%h claimed=%0d actual=%0d", tr.da, tr.sa, payload_size, actual_payload_size))
        end
      end
    end
    else if(tr.ether_type > 16'd1500 && tr.ether_type < 16'd1536) begin
      invalid_ethertype=1;
    end
    else begin
      `uvm_info("VALID_ETHERTYPE", $sformatf( "EtherType frame detected = %0h", tr.ether_type), UVM_HIGH)
    end    
    tr.payload = new[actual_payload_size];
    for(int i = actual_payload_size-1; i >= 0; i--)
      tr.payload[i] = frame_q[idx++];

    // CRC field: always the last 4 bytes in the queue
    tr.crc = {frame_q[idx], frame_q[idx+1], frame_q[idx+2], frame_q[idx+3]};

    // Running CRC over data bytes (offset..idx-1), skipping preamble+SFD
    next_crc = 32'hFFFF_FFFF;
    for(int i = offset; i < idx; i++)
      next_crc = tr.crc_32(next_crc, frame_q[i]);
    if(!residue_mode) begin
      next_crc = ~next_crc;
      `uvm_info("","\n*****************************ETH_TX_MONITOR***********************************\n",UVM_LOW)
      `uvm_info("TX MON UNPACKING", $sformatf( "\n\tpreamble=%0p \n\t sfd= %0h \n\t DA = %h\n\t SA          = %h\n\t ether_type = 0x%0h\n\t payload = %0d bytes\n\t CRC (frame) = 0x%h\n\t CRC (calc) = 0x%h\n\t CRC match = %0b\n\t frame size  = %0h\n\t VLAN_EN     = %0b\n\t TPID=%h PCP=%h DEI=%h VID=%h\n\t pause_en=%0b pause_opc=%h pause_time=%0d", tr.preamble,tr.sfd, tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == tr.crc), frame_q.size(), tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.pause_frame_en,tr.pause_opc, tr.pause_time), UVM_LOW)
      return (next_crc == tr.crc);
    end
    for(int i = 0; i < 4; i++)
      next_crc = tr.crc_32(next_crc, tr.crc[8*i +: 8]);
    next_crc = {<<{next_crc}};
    `uvm_info("","\n*****************************ETH_RX_MONITOR***********************************\n",UVM_LOW)
    `uvm_info("RX MON UNPACKING", $sformatf( "\n\t DA          = %h\n\t SA          = %h\n\t ether_type  = 0x%0h\n\t payload     = %0d bytes\n\t CRC (frame) = 0x%h\n\t residue     = 0x%h\n\t CRC OK      = %0b\n\t frame size  = %0h\n\t VLAN_EN     = %0b\n\t TPID=%h PCP=%h DEI=%h VID=%h\n\t pause_en=%0b pause_opc=%h", tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == 32'hC704DD7B), frame_q.size(),tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.pause_frame_en, tr.pause_opc), UVM_LOW)
    tr.crc_residue = next_crc;
    return (next_crc == 32'hC704DD7B);
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
    super.report_phase(phase);
    if(throughput_switch) begin
      if(tx_end_time > tx_start_time) begin
        real time_sec;
        time_sec = (tx_end_time - tx_start_time) * 1e-9;
	// Mac Throughput 
        tx_throughput_mbps = (tx_total_bytes * 8.0) / time_sec / 1e6;
 
	// Payload Throughput
        tx_payload_throughput_mbps = (tx_payload_bytes * 8.0) / time_sec / 1e6;
 
	if(tx_payload_throughput_mbps < 975.0) begin  //97.53% is payload, 2.47% is overhead
          `uvm_error("TX_PAYLOAD_THROUGHPUT_ERR", $sformatf("Payload Throughput FAILED Expected >= 983 Mbps Actual = %0.2f Mbps", tx_payload_throughput_mbps))
        end
        // Line Throughput
        tx_line_throughput_mbps = (tx_line_bytes * 8.0) / time_sec / 1e6;
	if(tx_line_throughput_mbps < 997.0) begin
          `uvm_error("TX_THROUGHPUT_ERR", $sformatf("Line Throughput FAILED Expected >= 997 Mbps Actual = %0.2f Mbps", tx_line_throughput_mbps))
        end   
        `uvm_info("THROUGHPUT", $sformatf(
        "\n=========================== TX THROUGHPUT Mac [%0d] ===========================\n",mac_no(mac_addr),
	  "Total TX Frames      : %0d\n", tx_pkt_count,
	  "Total TX Bytes       : %0d\n", tx_total_bytes,
	  "Start Time           : %0t\n", tx_start_time, 
	  "End Time             : %0t\n", tx_end_time,
	  "Time (sec)           : %0f\n", time_sec,
	  "Payload Bytes        : %0d\n", tx_payload_bytes,
	  "Line Bytes           : %0d\n", tx_line_bytes,
	  "MAC TX Throughput    : %0.2f Mbps\n", tx_throughput_mbps,
	  "Payload RX Throughput: %0.2f Mbps\n", tx_payload_throughput_mbps,
	  "Line RX Throughput   : %0.2f Mbps\n", tx_line_throughput_mbps,
        "\n=============================================================================="), UVM_LOW) 
      end
      if(rx_end_time > rx_start_time) begin
        real time_sec;
        time_sec = (rx_end_time - rx_start_time) * 1e-9;
	// Mac Throughput 
        rx_throughput_mbps = (rx_total_bytes * 8.0) / time_sec / 1e6;
 
        // Payload Throughput
        rx_payload_throughput_mbps = (rx_payload_bytes * 8.0) / time_sec / 1e6;
	if(rx_payload_throughput_mbps < 975.0) begin  //97.53% is payload, 2.47% is overhead
          `uvm_error("RX_PAYLOAD_THROUGHPUT_ERR", $sformatf("Payload Throughput FAILED Expected >= 983 Mbps Actual = %0.2f Mbps", rx_payload_throughput_mbps))
        end
 
        // Line Throughput
        rx_line_throughput_mbps = (rx_line_bytes * 8.0) / time_sec / 1e6;
	if(rx_line_throughput_mbps < 997.0) begin
          `uvm_error("RX_THROUGHPUT_ERR", $sformatf("Line Throughput FAILED Expected >= 997 Mbps Actual = %0.2f Mbps", rx_line_throughput_mbps))
        end
 
        `uvm_info("THROUGHPUT", $sformatf(
        "\n=========================== RX THROUGHPUT Mac [%0d] ===========================\n",mac_no(mac_addr),
	  "Total RX Frames      : %0d\n", rx_pkt_count,
	  "Total RX Bytes       : %0d\n", rx_total_bytes,
	  "Start Time           : %0t\n", rx_start_time, 
	  "End Time             : %0t\n", rx_end_time,
	  "Time (sec)           : %0f\n", time_sec,
	  "Payload Bytes        : %0d\n", rx_payload_bytes,
	  "Line Bytes           : %0d\n", rx_line_bytes,
	  "MAC RX Throughput    : %0.2f Mbps\n", rx_throughput_mbps,
	  "Payload RX Throughput: %0.2f Mbps\n", rx_payload_throughput_mbps,
	  "Line RX Throughput   : %0.2f Mbps\n", rx_line_throughput_mbps,
        "\n=============================================================================="), UVM_LOW) 
      end
    end
  endfunction
endclass



