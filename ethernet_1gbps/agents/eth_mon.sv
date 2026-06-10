`define v_inf v_intf.MON_MP.mon_cb
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

  function new(string name="eth_mon", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  //------------------------------------------------------------
  // BUILD
  //------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);
    if(!uvm_config_db #(virtual eth_gmii_interface)::get(this,"","vif",v_intf))
      `uvm_fatal("MON","VIF CONNECTION FAILED")
  endfunction

  //------------------------------------------------------------
  // RUN                                                        
  //------------------------------------------------------------
  task run_phase(uvm_phase phase);
    reset_counters();
    wait(v_intf.rst);
    fork
      tx_mon();
      rx_mon();
    join_none
  endtask

  //------------------------------------------------------------
  // TX MONITOR
  //------------------------------------------------------------
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
    bit carrier_ext_seen;
    int carrier_ext_cnt;
    bit pkt_bad;
    int min_payload;
    tx_ipg_violation_count=`IPG_COUNT;

    forever begin
      if(!`v_inf.TX_EN) begin
        tx_ipg_violation_count += 8;
        @(posedge v_intf.TX_CLK);
      end
      tx_frame_q.delete();
      collision_seen       = 0;
      crc_ok               = 0;
      da_match             = 0;
      byte_cnt             = 0;
      invalid_ethertype_tx = 0;
      bad_preamble_tx      = 0;
      bad_sfd_tx 	   = 0;
      tx_er_seen           = 0;
      len_mismatch_tx      = 0;
      pkt_bad              = 0;

      if(`v_inf.TX_EN) begin
	if(tx_ipg_violation_count < `IPG_COUNT) begin
	  statistics::v_uif[mac_addr].tx_ipg_violation_count++;
	  `uvm_error("TX_IPG_VIOLATION",$sformatf("IFG violation detected IFG=%0d bit-times",tx_ipg_violation_count))
	end
	tx_ipg_violation_count = 0;
	//------------------------------------------------
	// CAPTURE FRAME
       	//------------------------------------------------
	//
	//DETECTNG COLLISION
	while(`v_inf.TX_EN) begin
	  if(`v_inf.COL)
	  collision_seen=1;
        //--------------------------------------------
        // TX_ER
        //--------------------------------------------
        if(`v_inf.TX_ER) begin
          pkt_bad   = 1;
          tx_er_seen = 1;
        end

        //--------------------------------------------
        // PREAMBLE CHECK
        //--------------------------------------------
        if(byte_cnt < 7) begin
          if(`v_inf.TXD != `PREAMBLE) begin
            pkt_bad = 1;
            bad_preamble_tx = 1;
          end
        end

        //--------------------------------------------
        // SFD CHECK
        //--------------------------------------------
        else if(byte_cnt == 7) begin
          if(`v_inf.TXD != `SFD) begin
            pkt_bad = 1;
            bad_sfd_tx = 1;
          end
        end
        //--------------------------------------------
        // STORE ONLY DA ONWARDS
        //--------------------------------------------
        tx_frame_q.push_back(`v_inf.TXD);
        byte_cnt++;
        @(posedge v_intf.TX_CLK);
      end

      //--------------------------------------------
      // Carrier extension detection
      //--------------------------------------------
      while(`v_inf.TXD == 8'h0F) begin
        carrier_ext_seen = 1;
        carrier_ext_cnt++;
        //addr_classify_tx(tr);
        @(posedge v_intf.TX_CLK);
      end
      if(carrier_ext_seen) begin
        `uvm_info("TX_CARRIER_EXT",$sformatf("Carrier extension bytes=%0d",carrier_ext_cnt),UVM_LOW)
      end  
      //------------------------------------------------
      // CREATE TR
      //------------------------------------------------
      tr = eth_seq_item::type_id::create("tr", this);
      if(!collision_seen) tx_pkt_count++;
      tr.tx_count=tx_pkt_count;

      //------------------------------------------------
      // DA EXTRACTION
      //------------------------------------------------
      tx_da = {
      tx_frame_q[8],
      tx_frame_q[9],
      tx_frame_q[10],
      tx_frame_q[11],
      tx_frame_q[12],
      tx_frame_q[13]
      };

      //------------------------------------------------
      // DA MATCH
      //------------------------------------------------
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

      //------------------------------------------------
      // COLLISION
      //------------------------------------------------

      if(collision_seen) begin
	statistics::v_uif[mac_addr].tx_collision_count++;
	half_duplex = 1;
        `uvm_info("TX_COLLISION_DETECTED",$sformatf("Collision detected frame_size=%0d",tx_frame_q.size()),UVM_LOW)
        continue;
      end

      if(carrier_ext_seen) begin
        statistics::v_uif[mac_addr].tx_carrier_ext_count++; 
        //addr_classify_tx(tr);
        `uvm_info("TX_CARRIER_EXT_SUMMARY",$sformatf( "Carrier extension bytes=%0d",carrier_ext_cnt),UVM_LOW)
      end

      //------------------------------------------------
      // UNPACK
      //------------------------------------------------
      crc_ok = frame_unpack(tr, tx_frame_q, 8, 0, len_mismatch_tx, invalid_ethertype_tx);
      if(tr.vlan_en) begin
        if(tr.TPID != 16'h8100) begin
          `uvm_error("VLAN_TPID", $sformatf( "Invalid TPID = %h", tr.TPID))
        end
      end
      //------------------------------------------------
      // ERROR CONDITIONS
      //------------------------------------------------
      if(!da_match)
        pkt_bad = 1;

      if(invalid_ethertype_tx)
        pkt_bad = 1;

      //------------------------------------------------
      // Length mismatch
      //------------------------------------------------
      if(len_mismatch_tx && tr.payload.size() >= 46)
        pkt_bad = 1;

      //------------------------------------------------
      // CRC
      //------------------------------------------------
      if(!crc_ok)
        pkt_bad = 1;

      //------------------------------------------------
      // ERROR PRINTS
      //------------------------------------------------
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
      //------------------------------------------------
      // CLASSIFICATION
      // ONLY ONCE
      //------------------------------------------------
      addr_classify_tx(tr);
      //------------------------------------------------
      // VLAN
      //------------------------------------------------
      if(tr.vlan_en)
        statistics::v_uif[mac_addr].tx_vlan_count++;
      //------------------------------------------------
      // RUNT / FRAGMENT
      //------------------------------------------------
      min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : `MIN_PAYLOAD_SIZE;
      if(tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin		
	if(crc_ok) begin
      	  statistics::v_uif[mac_addr].tx_runt_count++;
      	  //addr_classify_tx(tr);
      	  `uvm_info("TX_RUNT_PKT", $sformatf( "Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
      	  pkt_bad=1;
      	 end
      	 else begin
      	   statistics::v_uif[mac_addr].tx_fragment_count++;
      	   //addr_classify_tx(tr);
      	   pkt_bad = 1;
      	   `uvm_error("TX_FRAGMENT_PKT",$sformatf("Fragment detected payload=%0d",tr.payload.size()))
      	 end
      end    
      if(tr.payload.size()>1536) begin
      	if(crc_ok) begin
      	  statistics::v_uif[mac_addr].tx_jumbo_count++;
      	  `uvm_info("TX_JUMBO_PKT",$sformatf("Jumbo detected payload=%0d",tr.payload.size()),UVM_LOW)
      	 end
      	 else begin
      	   statistics::v_uif[mac_addr].tx_jabber_count++;
      	   `uvm_error("TX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))
	   pkt_bad=1;
      	 end
      end
      //================================================
      // BLOCK PAUSE TO SCOREBOARD
      //================================================
      if(tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin  
        statistics::v_uif[mac_addr].tx_good_pkt_count++;
        if(tr.pause_time == 0)
          statistics::v_uif[mac_addr].tx_pause_xon_count++;
        else
     	  statistics::v_uif[mac_addr].tx_pause_xoff_count++;
      	  `uvm_info("RX_PAUSE_BLOCK",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d", 
		  tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.pause_time),UVM_LOW)
       	  continue;
      	end
      	else if(tr.pfc_frame_en &&
      	  tr.pause_opc == 16'h0101 &&
      	  tr.ether_type == 16'h8808) begin
      	  statistics::v_uif[mac_addr].tx_pfc_count++;
      	  statistics::v_uif[mac_addr].tx_good_pkt_count++;
      	  //addr_classify_tx(tr);
      	  `uvm_info("RX_PFC_BLOCK","PFC frame blocked from scoreboard",UVM_LOW)
      	  continue;
      	end
      	else if(tr.ether_type == 16'h8808 &&
      	  tr.pause_opc != 16'h0001 &&
      	  tr.pause_opc != 16'h0101) begin
      	  statistics::v_uif[mac_addr].tx_control_pkt_count++;
      	  `uvm_info("RX_CONTROL",$sformatf("Unknown control packet opcode=%h sent to scoreboard",tr.pause_opc),UVM_LOW)
      	end
      	else begin
      	  `uvm_info("RX_NORMAL_PKT","RX packet",UVM_LOW)
      	end    
      	//------------------------------------------------
      	// WRITE ALWAYS
      	//------------------------------------------------
      	if(pkt_bad)
      	  tr.err_b=1;
      	//------------------------------------------------
      	// GOOD / BAD COUNTS
      	//------------------------------------------------
      	if(pkt_bad) begin
      	  statistics::v_uif[mac_addr].tx_bad_pkt_count++;
      	end
	else begin
	  statistics::v_uif[mac_addr].tx_good_pkt_count++;
	end
	tx_ap.write(tr);
      end
    end
  endtask 

  //------------------------------------------------------------
  // RX MONITOR
  //------------------------------------------------------------
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
    time last_pause_rx_time;
    bit [15:0] active_pause_time;
    bit len_mismatch_rx;
    bit rx_carrier_ext_seen;
    int rx_carrier_ext_count;
    rx_ipg_violation_count=`IPG_COUNT;
    rx_carrier_ext_seen=0;
    rx_carrier_ext_count=0;

    forever begin
      collision_seen_rx =0;
      while(!`v_inf.RX_DV)begin
       	rx_ipg_violation_count += 8;
       	@(posedge v_intf.RX_CLK);
      end
      rx_frame_q.delete();
      bad_pkt  = 0;
      byte_cnt = 0;
      len_mismatch_rx=0;
      bad_preamble  = 0;
      bad_sfd  = 0;
      rx_er_seen        = 0;
      invalid_ethertype=0;

      if(`v_inf.RX_DV) begin
       	if(rx_ipg_violation_count < `IPG_COUNT) begin
	  statistics::v_uif[mac_addr].rx_ipg_violation_count++;
	  `uvm_error("RX_IPG_VIOLATION",$sformatf("IFG violation detected IFG=%0d bit-times",rx_ipg_violation_count))
        end
        rx_ipg_violation_count=0;
        while(`v_inf.RX_DV) begin
          if(`v_inf.RX_ER) begin
            if(!bad_pkt)
              bad_pkt = 1;
            rx_er_seen = 1;
          end
          if(byte_cnt < 7) begin
            if(`v_inf.RXD != `PREAMBLE) begin
              if(!bad_pkt)
         	      bad_pkt = 1;
              bad_preamble = 1;
            end
          end
          else if(byte_cnt == 7) begin
            if(`v_inf.RXD != `SFD) begin
              if(!bad_pkt)
         	bad_pkt = 1;
              bad_sfd = 1;
            end
          end      
          else begin
            rx_frame_q.push_back(`v_inf.RXD);
          end
          byte_cnt++;
          @(posedge v_intf.RX_CLK);
        end
      end
      //--------------------------------------
      // Carrier extension handling
      //--------------------------------------
      while(`v_inf.RXD == 8'h0F) begin
	       rx_carrier_ext_seen = 1;
	       rx_carrier_ext_count++;
	       @(posedge v_intf.RX_CLK);
      end
      if(rx_carrier_ext_seen) begin
	statistics::v_uif[mac_addr].rx_carrier_ext_count++;
	half_duplex = 1;
	`uvm_info("RX_CARRIER_EXT",$sformatf("Carrier extension bytes=%0d",rx_carrier_ext_count),UVM_LOW)
      end
      
      if(`v_inf.COL)
        collision_seen_rx=1;

      //------------------------------------------------
      // create transaction
      //------------------------------------------------
      tr = eth_seq_item::type_id::create("tr", this);
      if(!`v_inf.COL)
       	rx_pkt_count++;
      tr.rx_count=rx_pkt_count;
      tr.agt_addr=mac_addr;

      //------------------------------------------------
      // DA extraction
      //------------------------------------------------
      rx_da = {
      rx_frame_q[0],
      rx_frame_q[1],
      rx_frame_q[2],
      rx_frame_q[3],
      rx_frame_q[4],
      rx_frame_q[5]
      }; 

      //------------------------------------------------
      // DA validation
      //------------------------------------------------
      da_match = 0;

      if(rx_da == mac_addr)
	da_match = 1;

      if(rx_da == 48'hFF_FF_FF_FF_FF_FF)
	da_match = 1;

      if(multi_mac_addr.exists(rx_da))
	da_match = 1;

      //------------------------------------------------
      // COLLISION
      //------------------------------------------------
      if(collision_seen_rx) begin
	half_duplex = 1;
        `uvm_info("RX_COLLISION",$sformatf("Collision detected frame_size=%0d",rx_frame_q.size()),UVM_LOW)
         continue;
      end
      //------------------------------------------------
      // bad preamble / sfd / rx_er
      //------------------------------------------------
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
        statistics::v_uif[mac_addr].rx_bad_pkt_count++;
	continue;
      end
      //------------------------------------------------
      // Invalid DA
      //------------------------------------------------
      if(!da_match) begin
	addr_classify_rx(tr);
       	statistics::v_uif[mac_addr].rx_bad_pkt_count++;
       	`uvm_error("RX_INVALID_DA", $sformatf("Invalid DA = %h", rx_da))
       	continue;
      end
      crc_ok = frame_unpack(tr, rx_frame_q, 0, 1, len_mismatch_rx,invalid_ethertype);
      if(invalid_ethertype) begin
	addr_classify_rx(tr);
	statistics::v_uif[mac_addr].rx_bad_pkt_count++;
	`uvm_error("RX_UNDEFINED_ETHERTYPE", $sformatf( "Dropping packet : Undefined EtherType = %0d", tr.ether_type))
	continue;
      end
      if(len_mismatch_rx && tr.payload.size() >= 46) begin
       	statistics::v_uif[mac_addr].rx_bad_pkt_count++;
 	addr_classify_rx(tr);
	`uvm_error("RX_LEN_DATA_MISMATCH", $sformatf( "Length mismatch DA=%h SA=%h payload=%0d", tr.da, tr.sa, tr.payload.size()))
	continue;
      end	
      if(tr.vlan_en) begin
	statistics::v_uif[mac_addr].rx_vlan_count++; 
	if(tr.TPID != 16'h8100) begin
	  `uvm_error("VLAN_TPID", $sformatf( "Invalid TPID = %h", tr.TPID))
        end
      end
      //------------------------------------------------
      // RUNT / FRAGMENT
      //------------------------------------------------
      min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : `MIN_PAYLOAD_SIZE;

      if(tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin
        if(crc_ok) begin
       	  addr_classify_rx(tr);
       	  statistics::v_uif[mac_addr].rx_runt_count++;
       	  statistics::v_uif[mac_addr].rx_bad_pkt_count++;
      	  `uvm_info("RX_RUNT_PKT", $sformatf( "Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
      	  continue;
      	end
      	else if(!collision_seen_rx) begin
      	  addr_classify_rx(tr);
      	  statistics::v_uif[mac_addr].rx_fragment_count++;
      	  statistics::v_uif[mac_addr].rx_bad_pkt_count++;
      	  `uvm_error("RX_FRAGMENT_PKT", $sformatf( "Fragment detected payload=%0d", tr.payload.size()))
      	  continue;
      	end
      end
      if(tr.payload.size()>1536) begin
       	if(crc_ok) begin
      	   statistics::v_uif[mac_addr].rx_jumbo_count++;
      	   addr_classify_rx(tr);
      	   `uvm_info("RX_JUMBO_PKT",$sformatf("Jumbo detected payload=%0d",tr.payload.size()),UVM_LOW)
      	end
      	else begin
      	  statistics::v_uif[mac_addr].rx_jabber_count++;
          statistics::v_uif[mac_addr].rx_bad_pkt_count++;
      	  addr_classify_rx(tr);
      	  `uvm_error("RX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))
      	  continue;
      	end
      end
      if(!crc_ok) begin
        addr_classify_rx(tr);
        statistics::v_uif[mac_addr].rx_bad_pkt_count++;
        `uvm_error("RX_CRC_DROP",$sformatf("Dropping packet : Bad FCS DA=%h SA=%h CRC=%h",tr.da, tr.sa, tr.crc))
        continue;
      end
      //------------------------------------------------
      // PAUSE FRAME
      //------------------------------------------------
      if(tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin
        statistics::pause_value[mac_addr]  = tr.pause_time;
        statistics::pause_flag[mac_addr]   = 1;
      	statistics::pause_update[mac_addr] = 1;
      	statistics::v_uif[mac_addr].rx_good_pkt_count++;
      	addr_classify_rx(tr);
      	if(tr.pause_time == 0)
      	  statistics::v_uif[mac_addr].rx_pause_xon_count++;
      	else
      	  statistics::v_uif[mac_addr].rx_pause_xoff_count++; 
      	`uvm_info("RX_PAUSE_BLOCK",$sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d", 
		  tr.pause_frame_en,tr.ether_type,tr.pause_opc,tr.pause_time),UVM_LOW)
      	continue;
      end
      //------------------------------------------------
      // PFC FRAME
      //------------------------------------------------
      else if(tr.pfc_frame_en && tr.pause_opc == 16'h0101 && tr.ether_type == 16'h8808) begin
      	statistics::v_uif[mac_addr].rx_pfc_count++;
      	statistics::v_uif[mac_addr].rx_good_pkt_count++;	
      	addr_classify_rx(tr);
      	for(int i=0;i<8;i++) begin
      	  if(tr.priority_en_vector[i]) begin
      	    statistics::pfc_value[mac_addr][i] = tr.pfc_pause_time[i];
      	    statistics::pfc_flag[mac_addr][i] = 1;
      	    statistics::pfc_update[mac_addr][i] = 1;
      	  end
      	end
      	`uvm_info("RX_PFC_BLOCK","PFC frame blocked from scoreboard",UVM_LOW)
      	continue;
      end
      else if(tr.ether_type == 16'h8808 && tr.pause_opc != 16'h0001 && tr.pause_opc != 16'h0101) begin
       	statistics::v_uif[mac_addr].rx_control_pkt_count++;
       	`uvm_info("RX_CONTROL",$sformatf("Unknown control packet opcode=%h sent to scoreboard",tr.pause_opc),UVM_LOW)
      end
      else begin
       	`uvm_info("RX_NORMAL_PKT","RX packet",UVM_LOW)
      end    
      if(tr.payload.size() > 9000) begin
       	statistics::v_uif[mac_addr].rx_super_jumbo_count++;
      end
      if(!bad_pkt && crc_ok) begin
        statistics::v_uif[mac_addr].rx_good_pkt_count++;
       	addr_classify_rx(tr);
      end
      //addr_classify_rx(tr);
      fork
	if(half_duplex) #20 rx_ap.write(tr);
      	else rx_ap.write(tr);
      join_none
    end
  endtask

  task addr_classify_rx(eth_seq_item tr);
    if(tr.da == 48'hFF_FF_FF_FF_FF_FF)
      statistics::v_uif[mac_addr].rx_broadcast_count++;
    else if(multi_mac_addr.exists(tr.da))
      statistics::v_uif[mac_addr].rx_multicast_count++;
    else
      statistics::v_uif[mac_addr].rx_unicast_count++;
  endtask

  task addr_classify_tx(eth_seq_item tr);
    if(tr.da == 48'hFF_FF_FF_FF_FF_FF)
      statistics::v_uif[mac_addr].tx_broadcast_count++;
    else if (tr.da[40]) begin
      foreach(tr.multi_mac_addr[i]) begin
	if(mac_addr!=tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tr.da)) begin
	  statistics::v_uif[mac_addr].tx_multicast_count++;
	  break;
	end
      end
    end
    else
      statistics::v_uif[mac_addr].tx_unicast_count++;
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

	// pfc frame extraction
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

        //-----------------------------------------
        // LENGTH FIELD
        //-----------------------------------------
        if(tr.ether_type <= 16'd1500 && !tr.pause_frame_en && !tr.pfc_frame_en) begin
          payload_size = int'(tr.ether_type);
          if(tr.vlan_en)
            min_payload = `VLAN_PAYLOAD_SIZE;
          else
            min_payload = `MIN_PAYLOAD_SIZE;
          `uvm_info("MON_LEN_CHECK", $sformatf( "ether_type(claimed)=%0d actual_payload=%0d", payload_size, actual_payload_size), UVM_LOW)

          //-------------------------------------
          // PAYLOAD < MIN PAYLOAD
          //-------------------------------------
          if(payload_size < min_payload) begin
            if(actual_payload_size != min_payload) begin
              len_mismatch = 1;
              `uvm_error("MON_PADDING_ERROR", $sformatf( "Wrong padding length=%0d actual=%0d expected=%0d", 
		      payload_size, actual_payload_size, min_payload))
            end
          end

          //-------------------------------------
          // NORMAL LENGTH CHECK
          //-------------------------------------
          else begin
            if(payload_size != actual_payload_size) begin
              len_mismatch = 1;
              `uvm_error("MON_LEN_MISMATCH", $sformatf( "DA=%h SA=%h claimed=%0d actual=%0d", 
		      tr.da, tr.sa, payload_size, actual_payload_size))
            end
          end
        end

        //-----------------------------------------
        // UNDEFINED RANGE
        //-----------------------------------------
        else if(tr.ether_type > 16'd1500 && tr.ether_type < 16'd1536) begin
    	  invalid_ethertype=1;
	end

        //-----------------------------------------
        // VALID ETHERTYPE
        //-----------------------------------------
        else begin
          `uvm_info("VALID_ETHERTYPE", $sformatf( "EtherType frame detected = %0h", tr.ether_type), UVM_LOW)
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
	   `uvm_info("TX MON UNPACKING", $sformatf( "\n\tpreamble=%0p \n\t sfd= %0h \n\t DA = %h\n\t SA          = %h\n\t ether_type = 0x%0h\n\t payload = %0d bytes\n\t CRC (frame) = 0x%h\n\t CRC (calc) = 0x%h\n\t CRC match = %0b\n\t frame size  = %0h\n\t VLAN_EN     = %0b\n\t TPID=%h PCP=%h DEI=%h VID=%h\n\t pause_en=%0b pause_opc=%h pause_time=%0d", tr.preamble,tr.sfd, tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == tr.crc), frame_q.size(), tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.pause_frame_en, tr.pause_opc, tr.pause_time), UVM_LOW)
	     return (next_crc == tr.crc);
          end
          for(int i = 0; i < 4; i++)
	    next_crc = tr.crc_32(next_crc, tr.crc[8*i +: 8]);
          next_crc = {<<{next_crc}};
          `uvm_info("RX MON UNPACKING", $sformatf( "\n\t DA          = %h\n\t SA          = %h\n\t ether_type  = 0x%0h\n\t payload     = %0d bytes\n\t CRC (frame) = 0x%h\n\t residue     = 0x%h\n\t CRC OK      = %0b\n\t frame size  = %0h\n\t VLAN_EN     = %0b\n\t TPID=%h PCP=%h DEI=%h VID=%h\n\t pause_en=%0b pause_opc=%h", tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == 32'hC704DD7B), frame_q.size(), tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.pause_frame_en, tr.pause_opc), UVM_LOW)
	     return (next_crc == 32'hC704DD7B);
  endfunction



  //------------------------------------------------------------
  // UPDATE UI
  //------------------------------------------------------------
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
    statistics::v_uif[mac_addr].tx_super_jumbo_count   = 0;
    statistics::v_uif[mac_addr].tx_jabber_count        = 0;
    statistics::v_uif[mac_addr].tx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_count           = 0;
    statistics::v_uif[mac_addr].tx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].tx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].tx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].tx_control_pkt_count   = 0;

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
    statistics::v_uif[mac_addr].rx_super_jumbo_count   = 0;
    statistics::v_uif[mac_addr].rx_jabber_count        = 0;
    statistics::v_uif[mac_addr].rx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_count           = 0;
    statistics::v_uif[mac_addr].rx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].rx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].rx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].rx_control_pkt_count   = 0;
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
    `uvm_info("COUNTER_REPORT", $sformatf("\n================ COUNTER SUMMARY =================\nMAC_ADDR=%h
   \n---------------- MAC %0d : TX COUNTERS ----------------\n",mac_addr, mac_no(mac_addr),
   "TX Good Packets          = %0d\n",statistics::v_uif[mac_addr].tx_good_pkt_count,      
   "TX Bad Packets           = %0d\n",statistics::v_uif[mac_addr].tx_bad_pkt_count,
   "TX Collision             = %0d\n",statistics::v_uif[mac_addr].tx_collision_count,
   "TX Unicast               = %0d\n",statistics::v_uif[mac_addr].tx_unicast_count,
   "TX Multicast             = %0d\n",statistics::v_uif[mac_addr].tx_multicast_count,
   "TX Broadcast             = %0d\n",statistics::v_uif[mac_addr].tx_broadcast_count,
   "TX Runt                  = %0d\n",statistics::v_uif[mac_addr].tx_runt_count,
   "TX Fragment              = %0d\n",statistics::v_uif[mac_addr].tx_fragment_count,
   "TX Jumbo                 = %0d\n",statistics::v_uif[mac_addr].tx_jumbo_count,
   "TX Super Jumbo           = %0d\n",statistics::v_uif[mac_addr].tx_super_jumbo_count,
   "TX Jabber                = %0d\n",statistics::v_uif[mac_addr].tx_jabber_count,
   "TX Pause                 = %0d\n",statistics::v_uif[mac_addr].tx_pause_count,
   "TX VLAN                  = %0d\n",statistics::v_uif[mac_addr].tx_vlan_count,
   "TX IPG Violation         = %0d\n",statistics::v_uif[mac_addr].tx_ipg_violation_count,
   "TX PFC                   = %0d\n",statistics::v_uif[mac_addr].tx_pfc_count,
   "TX_carrier_ext_cnt       = %0d\n",statistics::v_uif[mac_addr].tx_carrier_ext_count,
   "TX Pause XON             = %0d\n",statistics::v_uif[mac_addr].tx_pause_xon_count,
   "Tx Pause XOFF            = %0d\n",statistics::v_uif[mac_addr].tx_pause_xoff_count,
   "TX control pkt           = %0d\n",statistics::v_uif[mac_addr].tx_control_pkt_count,
   "---------------- MAC %0d : RX COUNTERS ----------------\n",mac_no(mac_addr),
   "RX Good Packets          = %0d\n", statistics::v_uif[mac_addr].rx_good_pkt_count,
   "RX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].rx_bad_pkt_count,
   "RX Unicast               = %0d\n", statistics::v_uif[mac_addr].rx_unicast_count,
   "RX Multicast             = %0d\n", statistics::v_uif[mac_addr].rx_multicast_count,
   "RX Broadcast             = %0d\n", statistics::v_uif[mac_addr].rx_broadcast_count,
   "RX Runt                  = %0d\n", statistics::v_uif[mac_addr].rx_runt_count,
   "RX Fragment              = %0d\n", statistics::v_uif[mac_addr].rx_fragment_count,
   "RX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].rx_jumbo_count,
   "RX Super Jumbo           = %0d\n", statistics::v_uif[mac_addr].rx_super_jumbo_count,
   "RX Jabber                = %0d\n", statistics::v_uif[mac_addr].rx_jabber_count,
   "RX Pause                 = %0d\n", statistics::v_uif[mac_addr].rx_pause_count,
   "RX VLAN                  = %0d\n", statistics::v_uif[mac_addr].rx_vlan_count,
   "RX PFC                   = %0d\n", statistics::v_uif[mac_addr].rx_pfc_count,
   "RX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].rx_ipg_violation_count,
   "RX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].rx_carrier_ext_count,
   "RX Pause XON             = %0d\n", statistics::v_uif[mac_addr].rx_pause_xon_count,
   "Rx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].rx_pause_xoff_count,
   "RX control pkt           = %0d\n", statistics::v_uif[mac_addr].rx_control_pkt_count,
   "\n================================================"), UVM_NONE)
  endfunction
endclass



