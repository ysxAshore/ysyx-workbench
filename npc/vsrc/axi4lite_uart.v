module axi4lite_uart #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input clk,
  input rst,

  //ar  
  input arvalid,
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
  input [3:0] wstrb,
  input [DATA_WIDTH - 1 : 0] wdata,
  output wready,

  //b
  input bready,
  output reg bvalid,
  output reg [1:0] bresp
);
    reg [7:0] uart_char;

	assign awready = 1'b1; //总是可以接受写请求

	reg [3:0] delay_cnt;
	reg pending_read;

	wire [3:0] rand_delay;
	lfsr4 lfsr(.clk(clk), .rst(rst), .rnd(rand_delay));

	// aw 和 w 通道应该是解耦的 即允许同时发送awaddr和wdata
	// 因此需要使用reg暂存发来的wdata wstrb awaddr
	// 当他们都有效时 就可以发送写请求
	reg [ADDR_WIDTH - 1 : 0] reg_awaddr;
	reg [DATA_WIDTH - 1 : 0] reg_wdata;
	reg [3 : 0] reg_wstrb;
	reg aw_regValid;
	reg w_regValid;

	reg pending_write;

	assign awready = ~aw_regValid;
	assign wready = ~w_regValid;

	always @(posedge clk) begin
		if(~rst) begin
			bvalid <= 1'b0;
			aw_regValid <= 1'b0;
			w_regValid <= 1'b0;
			pending_write <= 1'b0;
            uart_char <= 8'h0;
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
                    uart_char <= reg_wdata[7:0];
					
                    //调用verilog函数实现uart
                    $write("%c",reg_wdata[7:0]);
                    $fflush;
                    
                    bvalid <= 1'b1;
					bresp <= 2'b0;

					pending_write <= 1'b0;
				end else begin
					delay_cnt <= delay_cnt - 4'b1;
				end
			end

			if(bvalid && bready) begin
				bvalid <= 1'b0;
			end
		end
	end
	
endmodule