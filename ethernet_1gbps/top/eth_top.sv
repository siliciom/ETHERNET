import uvm_pkg::*;
`include "uvm_macros.svh"
`include "../config/eth_pkg.sv"

module eth_top;
  bit clk;
  bit rst;
  bit mode = 1;
   
  // Intermediate Signals---------------------------------------
  logic [7:0] txd   [`NO_OF_AGENTS];
  logic       tx_en [`NO_OF_AGENTS];
  logic       tx_er [`NO_OF_AGENTS];

  logic [7:0] rxd_fd   [`NO_OF_AGENTS];
  logic       rx_dv_fd [`NO_OF_AGENTS];
  logic       rx_er_fd [`NO_OF_AGENTS];
  
  logic [7:0] rxd_hd   [`NO_OF_AGENTS];
  logic       rx_dv_hd [`NO_OF_AGENTS];
  logic       rx_er_hd [`NO_OF_AGENTS];
  
  logic [7:0] rxd   [`NO_OF_AGENTS];
  logic       rx_dv [`NO_OF_AGENTS];
  logic       rx_er [`NO_OF_AGENTS];
  
  logic       col   [`NO_OF_AGENTS];
  logic       crs   [`NO_OF_AGENTS];
  
  
  bit [47:0]  mac_uni[`NO_OF_AGENTS];
  bit         mac_multi[`NO_OF_AGENTS][bit [47:0]];
  int 	      route_da[`NO_OF_AGENTS][int];
  bit [7:0]   txd_buffer[`NO_OF_AGENTS][$];
  bit 	      tx_en_buffer[`NO_OF_AGENTS][$];
  bit 	      tx_er_buffer[`NO_OF_AGENTS][$];
  int 	      byte_count[`NO_OF_AGENTS];
  int 	      route_byte_count[`NO_OF_AGENTS];
  int 	      prev_byte_count[`NO_OF_AGENTS];
  bit 	      routing[`NO_OF_AGENTS];
  bit 	      sticky[`NO_OF_AGENTS];
  bit 	      ipg[`NO_OF_AGENTS];
  
  
  //----------------------------------------------------------

  // Coverting frequency from MHz to ns
  parameter real HALF_PERIOD = 1000 / (2 * `FREQ_IN_MHZ);
  
  eth_gmii_interface gmii_if[`NO_OF_AGENTS](rst);
  eth_ui_interface ui_inf[`NO_OF_AGENTS]();

  // Seting GMII Intf to Config_db
  genvar i;
  generate
    for (i = 0; i < `NO_OF_AGENTS; i++) begin : gen_config
      initial begin
        uvm_config_db#(virtual eth_gmii_interface)::set(
          null,
          $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", i),
          "vif",
          gmii_if[i]
        );
        
      end
      assign gmii_if[i].TX_CLK = clk;
      assign gmii_if[i].RX_CLK = clk;
      assign txd[i]   = gmii_if[i].TXD;
      assign tx_en[i] = gmii_if[i].TX_EN;
      assign tx_er[i] = gmii_if[i].TX_ER;
      
    end

  endgenerate
  
  // Initializing the unicast and multicast mac addresses for routing between
  // mac's and getting duplex modes
  initial begin
    mac_unicast(mac_uni);
    mac_multicast(mac_multi);
    uvm_config_db#(bit)::wait_modified(null,"","mode");
    if(!(uvm_config_db#(bit)::get(null,"","mode",mode)))
      `uvm_info("UVM_TOP","MODE FAIL,Can't able to get mode", UVM_LOW);
  end
  
  // initializing the statistics virtual interface with mac addr
  generate
  for(i=0; i<`NO_OF_AGENTS; i++) begin
    initial begin
      statistics::v_uif[mac_uni[i]] = ui_inf[i];
    end
  end
  endgenerate
  
  
  // Interconnect logic for Full Duplex
  always @(posedge clk) begin

   if(!rst && mode) begin
     for (int j = 0; j < `NO_OF_AGENTS; j++) begin
                rxd_fd[j]   <= 0;
                rx_dv_fd[j] <= 0;
                rx_er_fd[j] <= 0;
     end

   end

    if (rst && mode) begin

      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        
        if(tx_en[i]) sticky[i] = 1;

        // capture phase
        if (tx_en[i]) begin
          txd_buffer[i].push_back(txd[i]);
          tx_en_buffer[i].push_back(tx_en[i]);
          tx_er_buffer[i].push_back(tx_er[i]);
          byte_count[i]++;
        end
        else begin
          if(sticky[i]) prev_byte_count[i] = byte_count[i];
          byte_count[i]=0;
          sticky[i] = 0;
        end

        // detect DA (after 14 bytes)
        if (tx_en[i] && byte_count[i] == 14 && !routing[i]) begin
          
          bit [47:0] da;

          da = {
            txd_buffer[i][txd_buffer[i].size()-6], txd_buffer[i][txd_buffer[i].size()-5], txd_buffer[i][txd_buffer[i].size()-4],
            txd_buffer[i][txd_buffer[i].size()-3], txd_buffer[i][txd_buffer[i].size()-2], txd_buffer[i][txd_buffer[i].size()-1]
          };

          
          if(da==48'hFFFFFFFFFFFF) begin
            for(int j=0;j<`NO_OF_AGENTS;j++) begin
              if(i!=j)
                route_da[i][j] = 1;
            end
          end
          else begin
            if(!da[40]) begin

              for (int j = 0; j < `NO_OF_AGENTS; j++) begin
                if (i != j && mac_uni[j] == da)
                  route_da[i][j] = 1;
                if(j==`NO_OF_AGENTS-1 && route_da[i].num==0) begin
                  if(j!=i)
                    route_da[i][j] = 1;
                  else
                    route_da[i][j-1] = 1;
                end
              end
            end
            else begin
	      for(int j = 0; j < `NO_OF_AGENTS; j++) begin
		if(i != j && mac_multi[j].exists(da))
	          route_da[i][j] = 1;

	        if(j==`NO_OF_AGENTS-1 && route_da[i].num==0) begin
                  if(j!=i)
                    route_da[i][j] = 1;
                  else
                    route_da[i][j-1] = 1;
                end
	      end
      	    end
	        
          end

          routing[i] = 1;
          route_byte_count[i] = 0;
          
        end

        // forwarding phase
        if (routing[i]) begin

          if (txd_buffer[i].size() > 0) begin

            bit [7:0] data;
            bit       dv;
            bit       err;

            data = txd_buffer[i].pop_front();
            dv   = tx_en_buffer[i].pop_front();
            err  = tx_er_buffer[i].pop_front();

            for (int j = 0; j < `NO_OF_AGENTS; j++) begin
              if (route_da[i].exists(j)) begin
                rxd_fd[j]   <= data;
                rx_dv_fd[j] <= dv;
                rx_er_fd[j] <= err;
              end
            end
            route_byte_count[i]++;
          end
        end

        // frame end
        if((route_byte_count[i]==prev_byte_count[i]) && routing[i]) begin
          routing[i] = 0;
          route_byte_count[i] = 0;
          prev_byte_count[i] = 0;
          ipg[i] <= 1;
        end
        
        if(ipg[i]) begin
          for (int j = 0; j < `NO_OF_AGENTS; j++) begin
              if (route_da[i].exists(j)) begin
                rxd_fd[j]   <= 0;
                rx_dv_fd[j] <= 0;
                rx_er_fd[j] <= 0;
              end
          end
          route_da[i].delete();
          ipg[i] = 0;
        end
      end
    end
  end

  ///////////////////////////  
 
  // Half Duplex interconnect
  always_comb begin 
    
    int tx_count;
    int tx_index;
    tx_count = 0;
    tx_index = -1;
    
   
    //Default Assignments
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      rxd_hd[i]   = 0;
      rx_dv_hd[i] = 0;
      rx_er_hd[i] = 0;
      col[i]   = 0;
      crs[i]   = 0;
  	end
    
    if(rst) begin
  
      if (mode==0) begin // Half-Duplex
        
        tx_count = 0;

        for(int i=0; i<`NO_OF_AGENTS; i++) begin
          if(tx_en[i] || tx_er[i]) begin
            tx_count++;
            tx_index=i;
          end
        end

        if(tx_count==1) begin
          for(int i=0; i<`NO_OF_AGENTS; i++) begin
            if(i!=tx_index) begin
              rxd_hd[i]   = txd[tx_index];
              rx_dv_hd[i] = tx_en[tx_index];
              rx_er_hd[i] = tx_er[tx_index];
              crs[i]   = 1;
              col[i]   = 0;
              crs[tx_index]   = 1;
              col[tx_index]   = 0;
            end
          end
        end

        if(tx_count>1) begin
          for(int i=0; i<`NO_OF_AGENTS; i++) begin
            col[i] = 1;
            rx_er_hd[i] = 0;
            crs[i] = 1;
          end
        end
        
        if(!tx_count) begin
          for(int i=0; i<`NO_OF_AGENTS; i++) begin
            col[i] = 0;
            rx_er_hd[i] = 0;
            crs[i] = 0;
          end
        end
        
        
      end
      
    end
    
  end
 

  // Connecting the variables from duplex interconnect to intermediate variables 
  always_comb begin
    for (int i=0; i<`NO_OF_AGENTS; i++) begin
      if (mode) begin
        rxd[i]   = rxd_fd[i];
        rx_dv[i] = rx_dv_fd[i];
        rx_er[i] = rx_er_fd[i];
      end else begin
        rxd[i]   = rxd_hd[i];
        rx_dv[i] = rx_dv_hd[i];
        rx_er[i] = rx_er_hd[i];
      end
    end
  end
  
  // connecting intermediate variables with GMII Rx Signals  
  generate
    for(i=0; i<`NO_OF_AGENTS; i++) begin : gen_connect_rx
      assign gmii_if[i].RXD   = rxd[i];
      assign gmii_if[i].RX_DV = rx_dv[i];
      assign gmii_if[i].RX_ER = rx_er[i];
      assign gmii_if[i].COL   = col[i];
      assign gmii_if[i].CRS   = crs[i];
    end
  endgenerate
  
  // Clock Generation 
  initial begin
    clk = 0;
    forever #(HALF_PERIOD) clk = ~clk; 
  end
   
  // Initializing the reset
  initial begin
    rst = 0;
    repeat (5) @(posedge clk);
    rst = 1;
  end
  
  // Starting the test  
  initial begin
    run_test("");
  end
  
  
endmodule
