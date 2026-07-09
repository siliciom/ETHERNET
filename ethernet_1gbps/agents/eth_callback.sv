class error_cb extends uvm_callback;
  `uvm_object_utils(error_cb)
 
  bit bad_fcs_en;
  bit ctrl_error_en;
  bit len_mismatch_en;
  bit bad_preamble_en;
 
  function new(string name = "error_cb");
    super.new(name);
  endfunction
 
  virtual task inject_error(eth_seq_item tr);
    if (bad_fcs_en) begin
      tr.corrupt_fcs_en = 1;
      `uvm_info(get_name(), "Injected Bad FCS Error", UVM_MEDIUM)
    end
    if (ctrl_error_en) begin
      tr.err_b      = 1;
      tr.err_offset = $urandom_range(20,120);
      `uvm_info(get_name(), $sformatf("Injected Control Error at offset %0d", tr.err_offset), UVM_LOW)
    end
    if (len_mismatch_en) begin
      tr.ether_type = $urandom_range(46,1500);
      `uvm_info(get_name(), "Injected Length/Payload Mismatch", UVM_LOW)
    end
    if (bad_preamble_en) begin
      tr.preamble[4] = 8'hFF;
      `uvm_info(get_name(), "Injected Bad Preamble Error", UVM_LOW)
    end
  endtask
endclass
