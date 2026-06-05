`uvm_analysis_imp_decl(_ap_1)
`uvm_analysis_imp_decl(_ap_2)

class eth_scb extends uvm_scoreboard;
  `uvm_component_utils(eth_scb);

  uvm_analysis_imp_ap_1#(eth_seq_item, eth_scb) ai_1[`NO_OF_AGENTS];    
  uvm_analysis_imp_ap_2#(eth_seq_item, eth_scb) ai_2[`NO_OF_AGENTS];  

  eth_seq_item tx_tr;
  eth_seq_item rx_tr;

  // TX ARRAY
  // [source_agent][destination_agent][transaction_number]
  eth_seq_item tx_aa[int][int][int];

  // RX ARRAY
  // [source_agent][destination_agent][transaction_number]
  eth_seq_item rx_aa[int][int][int];
  int rx_count[int][int]; // [src][dst]
  int tx_count[int][int];

  function new(string name = "eth_scb", uvm_component parent = null);
    super.new(name,parent);

    // Creating memory for tlm analysis imp ports
    foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);

    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);

  endfunction   

  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction  

  function void write_ap_1(eth_seq_item tx_tr);

    int src_id;
    int dst_id;
    int txn_no;

    src_id = source_address(tx_tr);
    txn_no = tx_tr.tx_count;

    if(is_broadcast_addr(tx_tr.da)) begin

      foreach(ai_2[i]) begin

	 // source should not receive own broadcast
        if(i == src_id)
          continue;

        tx_aa[src_id][i][txn_no] = tx_tr;

        `uvm_info("SCB_BROADCAST_TX", $sformatf( "Stored BROADCAST TX : TX_AGENT[%0d] --> RX_AGENT[%0d] | TX_NO=%0d",
	       src_id, i, txn_no), UVM_LOW)

      end

      return;
    end

    if(is_multicast_addr(tx_tr)) begin

      foreach(ai_2[i]) begin

	if(i==src_id)
	  continue;

	if(tx_tr.multi_mac_addr[i].exists(tx_tr.da)) begin
	  tx_aa[src_id][i][txn_no] = tx_tr;
	  `uvm_info("SCB_MULTICAST_TX", $sformatf( "Stored MULTICAST TX : TX_AGENT[%0d] --> RX_AGENT[%0d] | TX_NO=%0d",
	    src_id, i, txn_no), UVM_LOW)
	end

      end

      return;
    end


    dst_id = destination_address(tx_tr);

    //-----------------------------------------
    // Invalid destination address
    // Store in special bucket
    //-----------------------------------------
    if(dst_id == -1) begin

      `uvm_info("SCB_INVALID_DA_STORE",
        $sformatf(
        "Invalid DA packet stored : DA=%012h",
        tx_tr.da),
        UVM_LOW)

    end

    //-----------------------------------------
    // Store TX transaction
    //-----------------------------------------
    
    tx_aa[src_id][dst_id][txn_no] = tx_tr;

    `uvm_info("SCB_TX",
      $sformatf(
      "Stored TX Packet : TX_AGENT[%0d] --> RX_AGENT[%0d] | TX_NO=%0d ",
      src_id,
      dst_id,
      txn_no),
      UVM_LOW)

  endfunction

  function bit is_error_pkt(eth_seq_item tr);

    // TX_ER
    if(tr.err_b)
      return 1;

    return 0;

  endfunction

  function bit is_broadcast_addr(bit [47:0] da);
    return (da == 48'hFFFF_FFFF_FFFF);
  endfunction

  function bit is_multicast_addr(eth_seq_item tr);
    foreach(tr.multi_mac_addr[i]) begin
      if(tr.multi_mac_addr[i].exists(tr.da))
	return 1;
    end
    return 0;
  endfunction

  function void write_ap_2(eth_seq_item rx_tr);
    int src_id;
    int dst_id;
    int txn_no;
    `uvm_info("SCB_RX", $sformatf("RX received AGT_ADDR = %012h", rx_tr.agt_addr), UVM_LOW)
    //-----------------------------------------
    // Decode SOURCE (SA → src_id)
    //-----------------------------------------
    src_id = source_address(rx_tr);

    if(src_id == -1) begin
      `uvm_error("SCB_INVALID_SA_RX",
        $sformatf("Invalid SA at RX : SA=%012h", rx_tr.sa))
      return;
    end

    txn_no = rx_tr.rx_count;

    //-----------------------------------------
    // BROADCAST CASE
    //-----------------------------------------
    if(is_broadcast_addr(rx_tr.da)) begin

      dst_id = broad_cast(rx_tr);

      if(dst_id == -1) begin
        `uvm_error("SCB_BC_FAIL", "Broadcast decode failed")
        return;
      end

    end

    else if(is_multicast_addr(rx_tr)) begin

      dst_id = multi_cast(rx_tr);

      if(dst_id == -1) begin
        `uvm_error("SCB_BC_FAIL", "Multicast decode failed")
        return;
      end

    end

    //-----------------------------------------
    // UNICAST CASE
    //-----------------------------------------
    else begin

      dst_id = destination_address(rx_tr);

      if(dst_id == -1) begin
        `uvm_error("SCB_INVALID_DA_RX", $sformatf("Invalid DA : DA=%012h", rx_tr.da))
        return;
      end

    end

    //-----------------------------------------
    // TX existence check
    //-----------------------------------------
    if(!tx_aa.exists(src_id) ||
     !tx_aa[src_id].exists(dst_id) ||
     !tx_aa[src_id][dst_id].exists(txn_no)) begin
    
      `uvm_error("SCB_EXTRA_RX", $sformatf( "RX received but matching TX not found : TX_AGENT[%0d] --> RX_AGENT[%0d] | TX_NO=%0d", 
	src_id, dst_id, txn_no))
      return;

    end


    //-----------------------------------------
    // BAD PACKET HANDLING
    //-----------------------------------------
    if(is_error_pkt( tx_aa[src_id][dst_id][txn_no])) begin

      `uvm_error("SCB_BAD_PKT", $sformatf("Bad packet reached RX | TX[%0d]->RX[%0d] TX_NO=%0d", src_id, dst_id, txn_no))

      rx_aa[src_id][dst_id][txn_no] = rx_tr;
      return;

    end

    //-----------------------------------------
    // GOOD PACKET → COMPARE
    //-----------------------------------------
    compare_packet( src_id, dst_id, txn_no, rx_tr.rx_count, tx_aa[src_id][dst_id][txn_no], rx_tr);
    //-----------------------------------------
    // DELETE TX AFTER SUCCESS
    //-----------------------------------------
    tx_aa[src_id][dst_id].delete(txn_no);

  endfunction

  function void check_phase(uvm_phase phase);

    super.check_phase(phase);

    foreach(tx_aa[src_id]) begin
      foreach(tx_aa[src_id][dst_id]) begin
        foreach(tx_aa[src_id][dst_id][txn_no]) begin

          //-----------------------------------------
          // BAD PACKET
          //-----------------------------------------
          if(is_error_pkt(tx_aa[src_id][dst_id][txn_no])) begin
            `uvm_info("SCB_BAD_PKT_PASS",
                $sformatf({
                "\n========================================================",
                "\nPASS : Bad Packet Correctly Dropped",
                "\n--------------------------------------------------------",
                "\nTX_AGENT        : %0d",
                "\nEXPECTED_RX     : %0d",
                "\nTX_TRANSACTION  : %0d",
                "\nDA              : %012h",
                "\nSA              : %012h",
                "\n========================================================"
                },
                  src_id,
                  dst_id,
                  txn_no,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa),
                  UVM_LOW)

            // delete only bad packet
            tx_aa[src_id][dst_id].delete(txn_no);


          end

          //-----------------------------------------
          // GOOD PACKET
          //-----------------------------------------
          else begin

            `uvm_error("SCB_MISSING_RX",
                  $sformatf({
                  "\n========================================================",
                  "\nFAIL : Good Packet Missing At RX",
                  "\n--------------------------------------------------------",
                  "\nTX_AGENT        : %0d",
                  "\nEXPECTED_RX     : %0d",
                  "\nTX_TRANSACTION  : %0d",
                  "\nDA              : %012h",
                  "\nSA              : %012h",
                  "\n========================================================"
                  },
                    src_id,
                    dst_id,
                    txn_no,
                    tx_aa[src_id][dst_id][txn_no].da,
                    tx_aa[src_id][dst_id][txn_no].sa))// keep the good packet for debugging purpose

          end


        end
      end
    end

  endfunction

  function void report_phase(uvm_phase phase);
	string test_name;
	int tx_left = 0;
	int rx_left = 0;

	super.report_phase(phase);

	//-----------------------------------------
	// Get testcase name (run.do friendly)
	//-----------------------------------------
	if (!$value$plusargs("UVM_TESTNAME=%s", test_name))
	  test_name = "UNKNOWN_TEST";

	//-----------------------------------------
	// Count TX leftovers
	//-----------------------------------------
	foreach (tx_aa[src]) begin
	  foreach (tx_aa[src][dst]) begin
	    tx_left += tx_aa[src][dst].num();
	  end
	end

	//-----------------------------------------
	// Count RX leftovers
	//-----------------------------------------
	foreach (rx_aa[src]) begin
	  foreach (rx_aa[src][dst]) begin
	    rx_left += rx_aa[src][dst].num();
	  end
	end

	//-----------------------------------------
	// SCOREBOARD SUMMARY
	//-----------------------------------------
	`uvm_info("SCB_SUMMARY",
	$sformatf({
	"\n====================================================",
	"\n SCOREBOARD SUMMARY",
	"\n====================================================",
	"\n TESTCASE NAME : %s",
	"\n----------------------------------------------------",
	"\n TX LEFT PACKETS : %0d",
	"\n RX LEFT PACKETS : %0d",
	"\n===================================================="
	},
	  test_name,
	  tx_left,
	  rx_left),
	  UVM_LOW)

	  //-----------------------------------------
	  // PASS / FAIL DECISION
	  //-----------------------------------------
	  if (tx_left == 0 && rx_left == 0) begin

	    `uvm_info("SCB_PASS",
	      $sformatf({
	      "\n====================================================",
	      "\n TEST PASSED",
	      "\n TESTCASE : %s",
	      "\n All TX/RX packets matched successfully",
	      "\n===================================================="
	      },
		test_name),
		UVM_LOW)

	    end
	    else begin

	      `uvm_error("SCB_FAIL",
		$sformatf({
		"\n====================================================",
		"\n TEST FAILED",
		"\n TESTCASE : %s",
		"\n TX LEFT : %0d",
		"\n RX LEFT : %0d",
		"\n===================================================="
		},
		  test_name,
		  tx_left,
		  rx_left))

	      end

   endfunction

  function void compare_packet(
    int tx_id,
    int rx_id,
    int tx_no,
    int rx_no,
    eth_seq_item tx_tr,
    eth_seq_item rx_tr);
    bit pass = 1;

    if(tx_tr.da !== rx_tr.da) begin
      `uvm_error("SCB_DA",
              $sformatf("DA mismatch: TX=%012h RX=%012h",
              tx_tr.da, rx_tr.da))
      pass = 0;
    end

    if(tx_tr.sa !== rx_tr.sa) begin
      `uvm_error("SCB_SA",
              $sformatf("SA mismatch: TX=%012h RX=%012h",
              tx_tr.sa, rx_tr.sa))
      pass = 0;
    end
    // ---------------------------
    // EtherType compare
    // ---------------------------
    if (tx_tr.ether_type !== rx_tr.ether_type) begin
      `uvm_error("SCB",
              $sformatf("EtherType mismatch: TX=%0h RX=%0h",
              tx_tr.ether_type, rx_tr.ether_type))
      pass = 0;
    end

    // ---------------------------
    // Payload size compare
    // ---------------------------
    if (tx_tr.payload.size() != rx_tr.payload.size()) begin
      `uvm_error("SCB",
              $sformatf("Payload size mismatch: TX=%0d RX=%0d",
              tx_tr.payload.size(), rx_tr.payload.size()))
      pass = 0;
    end
    else begin
      foreach (tx_tr.payload[i]) begin
        if (tx_tr.payload[i] !== rx_tr.payload[i]) begin
          `uvm_error("SCB",
                  $sformatf("Payload mismatch byte[%0d]: TX=%0h RX=%0h",
                  i, tx_tr.payload[i], rx_tr.payload[i]))
          pass = 0;
        end
      end
    end
    // ---------------------------
    // VLAN compare
    // ---------------------------
    if (tx_tr.vlan_en !== rx_tr.vlan_en) begin
      `uvm_error("SCB_VLAN",
              $sformatf("VLAN_EN mismatch: TX=%0b RX=%0b",
              tx_tr.vlan_en, rx_tr.vlan_en))
      pass = 0;
    end

    if (tx_tr.vlan_en) begin

      if (rx_tr.TPID !== 16'h8100) begin
        `uvm_error("SCB_TPID",
                $sformatf("TPID mismatch: Expected=8100 RX=%04h",
                rx_tr.TPID))
        pass = 0;
      end

      if (tx_tr.TPID !== rx_tr.TPID) begin
        `uvm_error("SCB_TPID",
                $sformatf("TPID mismatch: TX=%04h RX=%04h",
                tx_tr.TPID, rx_tr.TPID))
        pass = 0;
      end

      if (tx_tr.PCP !== rx_tr.PCP) begin
        `uvm_error("SCB_PCP",
                $sformatf("PCP mismatch: TX=%0d RX=%0d",
                tx_tr.PCP, rx_tr.PCP))
        pass = 0;
      end

      if (tx_tr.DEI !== rx_tr.DEI) begin
        `uvm_error("SCB_DEI",
                $sformatf("DEI mismatch: TX=%0b RX=%0b",
                tx_tr.DEI, rx_tr.DEI))
        pass = 0;
      end

      if (tx_tr.VID !== rx_tr.VID) begin
        `uvm_error("SCB_VID",
                $sformatf("VID mismatch: TX=%0d RX=%0d",
                tx_tr.VID, rx_tr.VID))
        pass = 0;
      end
    end
    // ---------------------------
    // Final result
    // ---------------------------
    if (pass) begin

      `uvm_info("SCB_TRANS_NUM",
              $sformatf({
              "\nTX_TRANSACTION_NO = %0d",
              "\nRX_TRANSACTION_NO = %0d"
              },
                tx_no,
                rx_no),
                UVM_LOW)
      `uvm_info("SCB_COMPARE",
                  $sformatf({
                  "\n==============================================================================",
                  "\n%-18s : %-18s | %-18s : %-18s",
                  "\n==============================================================================",
                  "\n%-18s : %-18d | %-18s : %-18d",
                  "\n%-18s : %012h       | %-18s : %012h",
                  "\n%-18s : %012h       | %-18s : %012h",
                  "\n%-18s : %04h             | %-18s : %04h",
                  "\n%-18s : %-18h | %-18s : %-18h",
                  "\n%-18s : %08h           | %-18s : %08h",
                  "\n%-18s : %-18b | %-18s : %-18b",
                  "\n=============================================================================="
                  },

                    "EXPECTED (TX)", "", "ACTUAL (RX)", "",

                    "TX_AGENT", tx_id,
                    "RX_AGENT", rx_id,

                    "DA", tx_tr.da,
                    "DA", rx_tr.da,

                    "SA", tx_tr.sa,
                    "SA", rx_tr.sa,

                    "ETHER_TYPE", tx_tr.ether_type,
                    "ETHER_TYPE", rx_tr.ether_type,

                    "PAYLOAD_SIZE", tx_tr.payload.size(),
                    "PAYLOAD_SIZE", rx_tr.payload.size(),

                    "CRC", tx_tr.crc,
                    "CRC", rx_tr.crc,

                    "ERR_B", tx_tr.err_b,
                    "ERR_B", rx_tr.err_b
                    ),UVM_LOW)   

      if(tx_tr.vlan_en)
        `uvm_info("SCB_VLAN_INFO",
                    $sformatf({
                    "\n================ VLAN INFO ================",
                    "\nTX_VLAN_EN : %0b   | RX_VLAN_EN : %0b",
                    "\nTX_TPID    : %04h | RX_TPID    : %04h",
                    "\nTX_PCP     : %0d    | RX_PCP     : %0d",
                    "\nTX_DEI     : %0b    | RX_DEI     : %0b",
                    "\nTX_VID     : %0d | RX_VID     : %0d",
                    "\n==========================================="
                    },

                      tx_tr.vlan_en, rx_tr.vlan_en,
                      tx_tr.TPID,    rx_tr.TPID,
                      tx_tr.PCP,     rx_tr.PCP,
                      tx_tr.DEI,     rx_tr.DEI,
                      tx_tr.VID,     rx_tr.VID
                      ),
                        UVM_LOW)
         `uvm_info("SCB_RX_COUNT",
                          $sformatf("RX packet count received in SB = %0d",
                          rx_tr.rx_count),
                          UVM_LOW)
      end
      else begin

      `uvm_error("SCB_FAIL",
                          $sformatf("Packet mismatch: TX agent[%0d] -> RX agent[%0d]",
                          tx_id, rx_id))
    end

  endfunction


  function int source_address(eth_seq_item tx_tr);

    for(int i = 0; i < `NO_OF_AGENTS; i++) begin

      if(tx_tr.sa == tx_tr.mac_addr[i])
        return i;

    end

    `uvm_error("SB_INVALID_SA",
                        $sformatf(
                        "Invalid Source Address Detected : SA=%012h",
                        tx_tr.sa))

     return -1;

  endfunction

  function int destination_address(eth_seq_item tx_tr);

    for(int i = 0; i < `NO_OF_AGENTS; i++) begin

      if(tx_tr.da == tx_tr.mac_addr[i])
        return i;

    end

    `uvm_info("SB_INVALID_DA",
                        $sformatf(
                        "Invalid Destination Address Detected : DA=%012h",
                        tx_tr.da),
                        UVM_LOW)

    return -1;

  endfunction

  function int broad_cast(eth_seq_item rx_tr);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      if(rx_tr.agt_addr == rx_tr.mac_addr[i])
	return i;
    end
  endfunction

  function int multi_cast(eth_seq_item rx_tr);
    for(int i=0; i<`NO_OF_AGENTS; i++) begin
      if(rx_tr.mac_addr[i]==rx_tr.agt_addr && rx_tr.multi_mac_addr[i].exists(rx_tr.da))
	return i;
    end
  endfunction

endclass
