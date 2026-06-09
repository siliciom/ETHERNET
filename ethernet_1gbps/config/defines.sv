`define NO_OF_AGENTS 2

`define FREQ_IN_MHZ 125
`define INTF_BIT_WIDTH 8

// Global mac addresses functions
function automatic void mac_unicast(ref bit [47:0] mac_t[`NO_OF_AGENTS]);
	for(int i = 0; i < `NO_OF_AGENTS; i++) begin
		mac_t[i] = {8'h00,8'(8'h50 + i),8'(8'h40 + i),8'(8'h30 + i),8'(8'h20 + i),8'(8'h10 + i)};
	end
endfunction

function automatic void mac_multicast(ref bit mac_t[`NO_OF_AGENTS][bit [47:0]]);
	for(int i=0; i < `NO_OF_AGENTS; i++) begin
		if(i%2==1)
			mac_t[i][{8'h01,8'h50,8'h40,8'h30,8'h20,8'h10}] = 1;

		mac_t[i][{8'h01,8'h80,8'hc2,8'h00,8'h00,8'h01}] = 1;
	end
endfunction
