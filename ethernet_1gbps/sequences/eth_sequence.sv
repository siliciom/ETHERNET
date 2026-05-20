class rand_data extends uvm_sequence #(eth_seq_item);
  eth_seq_item req;
  `uvm_object_utils(rand_data)
  
  function new (string name = "rand_data");
    super.new(name);
  endfunction
  
  task body();
    `uvm_info(get_type_name(), "rand_data: Inside Body", UVM_LOW)
    repeat(50) begin
    req = eth_seq_item::type_id::create("req");
    
    start_item(req);
    req.randomize();
    finish_item(req);
    end
  endtask
endclass


class virtual_seq extends uvm_sequence;
  rand_data seq1, seq2;

  `uvm_object_utils(virtual_seq)
  `uvm_declare_p_sequencer(eth_virtual_seqr) 

  function new(string name = "virtual_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info(get_type_name(), "virtual_seq: Inside Body", UVM_LOW)

    seq1 = rand_data::type_id::create("seq1");
    seq2 = rand_data::type_id::create("seq2");
    fork
      seq1.start(p_sequencer.mac_seqr_h[0]);
      //seq2.start(p_sequencer.mac_seqr_h[1]);
    join

  endtask
endclass
