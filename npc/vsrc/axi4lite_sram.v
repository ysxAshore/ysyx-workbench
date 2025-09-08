module axi4lite_sram #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input clk,
  input rst,

  //ar  
  input arvalid,
  input arid,
  input [ADDR_WIDTH - 1 : 0] araddr,
  output arready,

  //r
  input rready,
  output reg [1:0] rresp,
  output reg rvalid,
  output reg [DATA_WIDTH - 1 : 0] rdata,

  //aw
  input awvalid,
  input [ADDR_WIDTH - 1 : 0] awaddr,
  output awready,

  //w
  input wvalid,
  input [DATA_WIDTH - 1 : 0] wstrb,
  input [DATA_WIDTH - 1 : 0] wdata,
  output wready,

  //b
  input bready,
  output reg bvalid,
  output reg [1:0] bresp
);
  	assign arready = 'b1; //总是可以接受读请求
	assign awready = 'b1; //总是可以接受写请求

	reg [3:0] delay_cnt;
	reg pending_read;

    reg reg_arid;
    reg [ADDR_WIDTH - 1 : 0] reg_araddr;

	wire [3:0] rand_delay;
	lfsr4 lfsr(.clk(clk), .rst(rst), .rnd(rand_delay));

	// 通过 DPI-C 从内存读
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] inst_fetch(input bit[ADDR_WIDTH - 1 : 0] raddr);
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] vaddr_read(input bit[ADDR_WIDTH - 1 : 0] raddr,input bit[DATA_WIDTH - 1 : 0] len);
  	always @(posedge clk) begin
   		if(rst) begin
      		rvalid <= 'b0;
			pending_read <= 'b0;
		end else begin
    		if(arvalid && arready && ~pending_read) begin //在复位无效后开始取指
                reg_arid <= arid;
                reg_araddr <= araddr;
                
		   		delay_cnt <= rand_delay % 8;
		   		pending_read <= 'b1;
			end else if(pending_read) begin
				if(delay_cnt == 4'b0) begin
                    if(arid) rdata <= vaddr_read(reg_araddr, 'h4);
                    else rdata <= inst_fetch(reg_araddr);

      				rvalid <= 'b1;
      				rresp <= 'b0;
					pending_read <= 'b0;
				end else delay_cnt <= delay_cnt - 'b1;
			end
			if(rvalid && rready) rvalid <= 'b0;
  		end
	end
	// aw 和 w 通道应该是解耦的 即允许同时发送awaddr和wdata
	// 因此需要使用reg暂存发来的wdata wstrb awaddr
	// 当他们都有效时 就可以发送写请求
	reg [ADDR_WIDTH - 1 : 0] reg_awaddr;
	reg [DATA_WIDTH - 1 : 0] reg_wdata;
	reg [DATA_WIDTH - 1 : 0] reg_wstrb;
	reg aw_regValid;
	reg w_regValid;

	reg pending_write;

	assign awready = ~aw_regValid;
	assign wready = ~w_regValid;

	wire [DATA_WIDTH - 1 : 0] func_wlen = reg_wstrb == 'h1 ? 'h1 :
									 reg_wstrb == 'h3 ? 'h2 :
									 'h4;
	wire [DATA_WIDTH - 1 : 0] func_wdata = reg_wstrb == 'h1 ? {{(DATA_WIDTH - 8){1'b0}}, reg_wdata[7:0]} :
									  reg_wstrb == 'h3 ? {{(DATA_WIDTH - 16){1'b0}}, reg_wdata[15:0]} :
									  reg_wdata[31:0];

	import "DPI-C" function void vaddr_write(input bit[ADDR_WIDTH - 1 : 0] waddr,input bit[DATA_WIDTH - 1 : 0] wlen,input bit[DATA_WIDTH - 1 : 0] wdata);
	always @(posedge clk) begin
		if(rst) begin
			bvalid <= 1'b0;
			aw_regValid <= 1'b0;
			w_regValid <= 1'b0;
			pending_write <= 1'b0;
		end else begin
			if(awready && awvalid) begin
				aw_regValid <= 1'b1;
				reg_awaddr <= awaddr;
			end

			if(wready && wvalid) begin
				w_regValid <= 1'b1;
				reg_wdata <= wdata;
				reg_wstrb <= wstrb;
			end

			if(aw_regValid && w_regValid && ~pending_write) begin
				pending_write <= 1'b1;
				delay_cnt <= rand_delay % 8;
			end else if(pending_write) begin
				if(delay_cnt == 4'b0) begin
					aw_regValid <= 1'b0;
					w_regValid <= 1'b0;
					vaddr_write(reg_awaddr, func_wlen, func_wdata);
					bvalid <= 1'b1;
					bresp <= 2'b0;

					pending_write <= 1'b0;
				end else delay_cnt <= delay_cnt - 4'b1;
			end

			if(bvalid && bready) bvalid <= 1'b0;
		end
	end
	
endmodule

module lfsr4(
  input clk,
  input rst,
  output reg [3:0] rnd
);
  always @(posedge clk or negedge rst) begin
    if (!rst) rnd <= 4'hF; // 初始值不能为 0
    else rnd <= {rnd[2:0], rnd[3] ^ rnd[2]};
  end
endmodule