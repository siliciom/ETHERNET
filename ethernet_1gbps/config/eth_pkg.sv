
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "defines.sv"
  `include "statistics.sv"
  `include "../sequences/eth_seq_item.sv"
  

  `include "../agents/eth_mon.sv"
  `include "../agents/eth_drv.sv"
  `include "../agents/eth_seqr.sv"
  `include "../agents/eth_agnt.sv"

  `include "../env/eth_virtual_seqr.sv"
  `include "../env/eth_sbscr.sv"
  `include "../env/eth_scb.sv"
  `include "../env/eth_env.sv"

  `include "../sequences/eth_sequence.sv"
  `include "../sequences/eth_virtual_seq.sv"
  `include "../tests/eth_base_test.sv"
