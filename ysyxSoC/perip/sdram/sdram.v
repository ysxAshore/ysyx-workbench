module sdram(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 1:0] ba,
  input [ 1:0] dqm,
  inout [15:0] dq
);	

// STATE_W: 状态机宽度
localparam STATE_W = 2;
// SDRAM commands
localparam CMD_W             = 4;
localparam CMD_NOP           = 4'b0111;
localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_READ          = 4'b0101;
localparam CMD_WRITE         = 4'b0100;
localparam CMD_TERMINATE     = 4'b0110;
localparam CMD_PRECHARGE     = 4'b0010;
localparam CMD_REFRESH       = 4'b0001;
localparam CMD_LOAD_MODE     = 4'b0000;

// nop_t: 可以接受新的command 
//  	收到cmd_nop: 保持nop_t
//      收到cmd_active: 记录ra和ba, 进入nop_t
//      收到write: 记录ca,ba,data,dqm, 进入write_t
//      收到read: 记录ca,ba, 进入read_t
//      收到load_mode: 记录cas和burst_length, 进入nop_t
// write_t: 写数据
//		首先,在nop_t收到write命令时 记录下的信息可以作为一次写操作
//      之后,根据burst_length 再做其他写操作 这个时候其实收到的是cmd_nop
//      收到cmd_terminate: 结束写操作 不再发出突发写请求wvalid为false 回到nop_t
// read_t: 读数据
//      首先,在nop_t收到read命令时 记录下的信息可以作为一次读操作
//		之后,根据burst_length 再做其他读操作 这个时候其实收到的是cmd_nop
//      收到cmd_terminate: 结束读操作 不再发出突发读 回到nop_t
reg [STATE_W - 1 : 0] state;
typedef enum [1:0] {nop_t , read_t , write_t} state_t;

reg [12:0]row_a;
reg [8:0] col_a;
reg [1:0] bank_a;
reg [3:0] burst_length;
reg [15:0] wdata;
reg [1:0] wsel;

reg [3:0] now_burst;

wire [3:0] command = {cs,ras,cas,we};

wire rvalid = state == read_t && command != CMD_TERMINATE && now_burst < burst_length;
wire wvalid = state == write_t && command != CMD_TERMINATE && now_burst < burst_length;
wire [31:0] rdata;
assign dq = state == read_t ? rdata[15:0] : 16'bz;

sdram_cmd sdram_cmd_i(
	.clock(clk),
	.rvalid(rvalid),
	.wvalid(wvalid),
	.addr({8'b0, row_a, bank_a, col_a[8:0]}),
	.wsel(wsel),
	.wdata(wdata),
	.rdata(rdata)
);

 //cke是有一个从0~1的过程的 这里可以直接用cke作为复位
 always @(posedge clk) begin
  if(~cke) begin
	state <= nop_t;
  end else begin
	case (state)
		nop_t: begin //可以接受新的command
			state <= nop_t;
			col_a <= 9'h0;
			now_burst <= 4'h0;
			if(command == 4'h0) begin //只需要记录burst_length,cas_latency在外面有设置
				burst_length <= a[2:0] == 3'h0 ? 4'h1 : 
					            a[2:0] == 3'h1 ? 4'h2 :
								a[2:0] == 3'h2 ? 4'h4 :
								4'h8;
			end else if(command == 4'h3) begin //ACTIVE 接受新的row和bank
				row_a <= a;
				bank_a <= ba;
			end else if(command == 4'h4) begin //WRITE 接收col和bank,data,dqm
				bank_a <= ba;
				col_a <= a[8:0];
				wdata <= dq;
				wsel  <= dqm;
				state <= write_t;
			end else if(command == 4'h5) begin
				col_a <= a[8:0]; 
				bank_a <= ba;
				state <= read_t;
			end 
		end
		read_t: begin
			if(command == CMD_TERMINATE) begin
				state <= nop_t;
			end else if(now_burst < burst_length) begin
				now_burst <= now_burst + 4'h1;
				col_a <= col_a + 9'h1;
			end else begin
				state <= nop_t;
			end
		end
		write_t: begin
			if(command == 4'h6) begin
				state <= nop_t;
			end else if(now_burst < burst_length) begin
				wdata <= dq;
				wsel  <= dqm;
				col_a <= col_a + 9'h1;
				now_burst <= now_burst + 4'h1;
			end else begin
				state <= nop_t;
			end
		end
		default : state <= state;
	endcase
  end
 end

endmodule

import "DPI-C" function void sdram_read(input int addr,  output int data);
import "DPI-C" function void sdram_write(input int addr, input int data, input int wsel);

module sdram_cmd(
	input clock,
	input rvalid,
	input wvalid,
	
	input [31:0] addr,

	input [1:0] wsel, 
	input [15:0]wdata,
	output reg [31:0] rdata
);
	always @(posedge clock) begin
		if(rvalid) sdram_read(addr, rdata);
		if(wvalid) sdram_write(addr,{16'b0,wdata},{30'b0,wsel});
	end
endmodule