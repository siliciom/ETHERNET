class eth_seq_item extends uvm_sequence_item;
  `uvm_object_utils(eth_seq_item)
  
  function new(string name = "transaction");
    super.new(name);
  endfunction
  
  rand bit [7:0] data;
endclass
