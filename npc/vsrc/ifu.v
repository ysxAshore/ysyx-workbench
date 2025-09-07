module ifu #(parameter ADDR_WIDTH = 32, DATA_WIDTH = 32)(
	input clk,
	input rst,

  //ID2IF Bus
  input  id_to_if_valid,
  output if_to_id_ready,
	input  [ADDR_WIDTH - 1 : 0] id_to_if_bus,

  //IF2ID Bus
  input      id_to_if_ready,
  output reg if_to_id_valid,
  output     [DATA_WIDTH + ADDR_WIDTH - 1 : 0] if_to_id_bus,

  input  wb_to_if_done
);
  reg [ADDR_WIDTH - 1: 0] fetch_pc;
  reg fetch_valid;

  wire [ADDR_WIDTH - 1: 0] next_pc;
  assign next_pc = id_to_if_bus;

  wire [DATA_WIDTH - 1 : 0] inst;

  // 接收新的 PC
  wire accept_new_pc = id_to_if_valid && if_to_id_ready;

  //当前流水级false或者id级准备好接收信息 MCPU需要在WB完成后才能取新的
  assign if_to_id_ready = (!fetch_valid || id_to_if_ready) & wb_to_if_done;

  always @(posedge clk) begin
    if (rst) begin
      fetch_pc <= 'h8000_0000;
      fetch_valid <= 'b1;
      if_to_id_valid <= 'b0; //需要一个周期取指 在fetch_valid有效后延一周期置位if_to_id_valid
    end else begin
      // 更新fetch_pc取新指令
      if(accept_new_pc) begin
        fetch_pc <= next_pc;
        fetch_valid <= 'b1;
      end

      // 取指完毕 发出给id
      if(fetch_valid && id_to_if_ready) begin
        if_to_id_valid <= 'b1;
        fetch_valid <= 'b0;
      end else if(if_to_id_valid && id_to_if_ready)
        if_to_id_valid <= 'b0; 
      end
  end

  assign if_to_id_bus = {fetch_pc, inst};

  IFU_SRAM ifu_sram(
    .clk(clk),
    .rst(rst),
    .ren(fetch_valid),
    .addr(fetch_pc),
    .data(inst)
  );

endmodule

module IFU_SRAM #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input clk,
  input rst,
  input ren,
  input [ADDR_WIDTH - 1 : 0] addr,
  output reg [DATA_WIDTH - 1 : 0] data
);
  reg rst_done;

  // 通过 DPI-C 从内存读指令
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] inst_fetch(input bit[ADDR_WIDTH - 1 : 0] raddr);
  always @(posedge clk) begin
    if(rst) begin
        data <= 'h0000_0013;
    end else begin
        if(ren) data <= inst_fetch(addr);
    end
  end
endmodule