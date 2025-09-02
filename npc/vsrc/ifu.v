module ifu #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
	input                           clk,
	input                           rst,
	input      [ADDR_WIDTH - 1 : 0] dnpc,
	output reg [DATA_WIDTH - 1 : 0] inst,
	output reg [ADDR_WIDTH - 1 : 0] fectch_pc
);

	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] inst_fetch(input bit[ADDR_WIDTH - 1 : 0] raddr);
  reg rst_done;

  always @(posedge clk) begin
    if (rst) begin
      fectch_pc <= 'h8000_0000;
      inst      <= 'h0000_0013;   // NOP
      rst_done  <= 'b0;
    end else begin
      if (!rst_done) begin
        // 复位后的第一个周期,取指8000_0000
        rst_done  <= 'b1;
        inst      <= inst_fetch('h8000_0000);
      end else begin
        // 正常取指
        fectch_pc <= dnpc;
        inst      <= inst_fetch(dnpc);
      end
    end
  end

endmodule