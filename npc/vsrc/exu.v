module exu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(
	input  clk,
	input  rst,

	input  id_to_exe_valid,
	output exe_to_id_ready,
	input  [DATA_WIDTH * 3 + REG_ADDR_WIDTH + 19 - 1 : 0] id_to_exe_bus,

	input  mem_to_exe_ready,
	output exe_to_mem_valid,
	output [DATA_WIDTH * 2 + REG_ADDR_WIDTH + 4 - 1 : 0]exe_to_mem_bus


);
	reg exe_valid;

	reg [DATA_WIDTH - 1 : 0] aluSrc1;
	reg [DATA_WIDTH - 1 : 0] aluSrc2;
	reg [10 : 0] aluOp;
	reg d_regW;
	reg [REG_ADDR_WIDTH - 1 : 0] d_regAddr;
	reg [2 : 0] load_inst;
	reg [3 : 0] store_mask;
	reg [DATA_WIDTH - 1 : 0] store_data;

	assign exe_to_id_ready = ~exe_valid || mem_to_exe_ready;

	//AXI
	reg arvalid;
	wire arready;
	reg awvalid;
	wire awready;
	reg wvalid;
	wire wready;
	wire rvalid;
	wire rready = rvalid;
	wire [1:0] rresp;
	wire bvalid;
	wire bready = bvalid;
	wire [1:0] bresp;

	reg send_request_ar_aw;
	reg send_request_w;

	assign exe_to_mem_valid = exe_valid && load_inst != 3'b0 ? rvalid && rready && rresp == 2'b0 : 
							  exe_valid && store_mask != 4'b0 ? bvalid && bready && bresp == 2'b0 :
							  exe_valid;


	always @(posedge clk) begin
		if(rst) begin
			arvalid <= 'b0;
			awvalid <= 'b0;
			send_request_ar_aw <= 'b0;
			send_request_w <= 'b0;
		end else begin
			if (id_to_exe_valid && exe_to_id_ready) begin
				exe_valid <= 'b1;

				aluOp <= id_to_exe_bus[DATA_WIDTH * 3 + REG_ADDR_WIDTH + 19 - 1 : DATA_WIDTH * 3 + REG_ADDR_WIDTH + 8];
				aluSrc1 <= id_to_exe_bus[DATA_WIDTH * 3 + REG_ADDR_WIDTH + 8 - 1 : DATA_WIDTH * 2 + REG_ADDR_WIDTH + 8];
				aluSrc2 <= id_to_exe_bus[DATA_WIDTH * 2 + REG_ADDR_WIDTH  + 8 - 1 : DATA_WIDTH + REG_ADDR_WIDTH + 8];
				d_regW <= id_to_exe_bus[DATA_WIDTH + REG_ADDR_WIDTH + 7 : DATA_WIDTH + REG_ADDR_WIDTH + 7];
				d_regAddr <= id_to_exe_bus[DATA_WIDTH + REG_ADDR_WIDTH + 7 - 1 : DATA_WIDTH + 7];
				load_inst <= id_to_exe_bus[DATA_WIDTH + 7 - 1 : DATA_WIDTH + 4];
				store_mask <= id_to_exe_bus[DATA_WIDTH + 4 - 1 : DATA_WIDTH];
				store_data <= id_to_exe_bus[DATA_WIDTH - 1 : 0];
			end

			if(exe_valid) begin
				if(load_inst != 3'b0) begin
					if(~arvalid && ~send_request_ar_aw) begin
						arvalid <= 1'b1;
						send_request_ar_aw <= 1'b1;
					end else if(arvalid && arready) begin
						arvalid <= 1'b0;
					end
				end else if(store_mask != 4'b0) begin
					if(~awvalid && ~send_request_ar_aw) begin
						awvalid <= 1'b1;
						send_request_ar_aw <= 1'b1;
					end else if(awvalid && awready) begin
						awvalid <= 1'b0;
					end
					if(~wvalid && ~send_request_w) begin
						wvalid <= 1'b1;
						send_request_w <= 1'b1;
					end else if(wvalid && wready) begin
						wvalid <= 1'b0;
					end
				end 
			end

			if(rvalid && rready) begin
				send_request_ar_aw <= 1'b0;
			end

			if(bvalid && bready) begin
				send_request_ar_aw <= 1'b0;
				send_request_w <= 1'b0;
			end

			if(exe_to_mem_valid && mem_to_exe_ready) begin
				exe_valid <= 1'b0;
			end
		end	
	end

	wire [DATA_WIDTH - 1 : 0] aluResult;
	alu #(
		.DATA_WIDTH(DATA_WIDTH)
	) exe_alu(
		.aluOp(aluOp),
		.aluSrc1(aluSrc1),
		.aluSrc2(aluSrc2),
		.aluResult(aluResult)
	);

	wire [DATA_WIDTH - 1 : 0] load_data;
	//防止对齐位宽 这里设置为DATA_WIDTH
	wire [DATA_WIDTH - 1 : 0] rlen = load_inst == 3'h1 || load_inst == 3'h4 ? 'h1 :
									 load_inst == 3'h2 || load_inst == 3'h5 ? 'h2 :
									 'h4;


	LSU_SRAM lsu_sram (
	  .clk(clk),
	  .rst(rst),
	  .arvalid(arvalid),
	  .araddr(aluResult),
	  .arready(arready),
	  .rready(rready),
	  .rvalid(rvalid),
	  .rresp(rresp),
	  .rdata(load_data),
	  .awvalid(awvalid), // 未使用写通道
	  .awaddr(aluResult),
	  .awready(awready),
	  .wvalid(wvalid),
	  .wstrb(store_mask),
	  .wdata(store_data),
	  .wready(wready),
	  .bready(bready),
	  .bvalid(bvalid),
	  .bresp(bresp)
	);

	assign exe_to_mem_bus = {
		d_regW,
		d_regAddr,
		aluResult,
		load_inst,
		load_data
	};

endmodule

module alu #(DATA_WIDTH = 32)(
	input  [           10 : 0] aluOp,
	input  [DATA_WIDTH -1 : 0] aluSrc1,
	input  [DATA_WIDTH -1 : 0] aluSrc2,
	output [DATA_WIDTH -1 : 0] aluResult	
);
 	wire op_add  = aluOp[0];
 	wire op_sub  = aluOp[1];
 	wire op_slt  = aluOp[2];
 	wire op_sltu = aluOp[3];
 	wire op_and  = aluOp[4];
 	wire op_or   = aluOp[5];
 	wire op_xor  = aluOp[6];
 	wire op_sll  = aluOp[7];
 	wire op_srl  = aluOp[8];
 	wire op_sra  = aluOp[9];
 	wire op_lui  = aluOp[10];
  	
	wire [DATA_WIDTH -1   	 : 0] add_sub_result;
 	wire [DATA_WIDTH -1   	 : 0] slt_result;
 	wire [DATA_WIDTH -1   	 : 0] sltu_result;
 	wire [DATA_WIDTH -1   	 : 0] and_result;
 	wire [DATA_WIDTH -1   	 : 0] or_result;
 	wire [DATA_WIDTH -1   	 : 0] xor_result;
 	wire [DATA_WIDTH -1   	 : 0] lui_result;
 	wire [DATA_WIDTH -1   	 : 0] sll_result;
 	wire [DATA_WIDTH * 2 - 1 : 0] sr64_result;
 	wire [DATA_WIDTH -1   	 : 0] sr_result;

 	// 32-bit adder 作加减法操作
 	wire [DATA_WIDTH - 1 : 0] adder_a;  //加法器的加数a
 	wire [DATA_WIDTH - 1 : 0] adder_b;  //加法器的加数b
 	wire 					  adder_cin;  //加法器的低位进位
 	wire [DATA_WIDTH - 1 : 0] adder_result;  //加法结果
 	wire 					  adder_cout;  //加法器的进位输出

 	assign adder_a = aluSrc1;  //加数a不用变化
 	assign adder_b   = (op_sub | op_slt | op_sltu) ? ~aluSrc2 : aluSrc2;  //src1 - src2 rj-rk 加数b需要根据执行减法取反
 	assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1 : 1'b0;//因为b只是取反了，减法的话需要加1
 	assign {adder_cout, adder_result} = {1'b0,adder_a} + {1'b0,adder_b} + {{DATA_WIDTH{1'b0}},adder_cin};  //赋值计算

 	// ADD, SUB result
 	assign add_sub_result = adder_result;  //赋值最终的结果

 	// SLT result SLT结果如果src1小于src2那么置1,否则置0
 	assign slt_result[DATA_WIDTH - 1 : 1] = 'b0;  //rj < rk 1
 	assign slt_result[0] = (aluSrc1[DATA_WIDTH-1] & ~aluSrc2[DATA_WIDTH-1])  //src1是负数，src2是正数
 	    | ((aluSrc1[DATA_WIDTH-1] ~^ aluSrc2[DATA_WIDTH-1]) & adder_result[DATA_WIDTH-1]);//~^表示同或，src1和src2符号相同，src1<src2时，正数作差是负数，负数作差还是负数

 	// SLTU result
 	assign sltu_result[DATA_WIDTH - 1 : 1] = 'b0;
 	assign sltu_result[0]    = ~adder_cout;//无符号数比较，如果src1>src2时，高位进位输出1

 	// bitwise operation
 	assign and_result = aluSrc1 & aluSrc2;  //与结果
 	assign or_result = aluSrc1 | aluSrc2;  //或结果      
 	assign xor_result = aluSrc1 ^ aluSrc2;  //异或
 	assign lui_result = aluSrc2;  //12位立即数的符号扩展

 	// SLL result 
 	assign sll_result = aluSrc1 << aluSrc2[4:0];  //rj << i5

 	// SRL, SRA result
 	// {op_sra&alu_src1[DATA_WIDTH-1]}如果是算术右移，那么补全32个符号位；如果不是算术右移，那么补全32个0
 	assign sr64_result = {{32{op_sra & aluSrc1[DATA_WIDTH - 1]}}, aluSrc1[DATA_WIDTH - 1 : 0]} >> aluSrc2[4:0];  //rj >> i5 

 	assign sr_result = sr64_result[DATA_WIDTH-1:0];  //再取低位

 	// final result mux
 	assign aluResult = ({DATA_WIDTH{op_add|op_sub}} & add_sub_result)//多路选择，这里直接是根据op进行32位1扩展，全f与结果
 	    			  | ({DATA_WIDTH{op_slt       }} & slt_result)
 	    			  | ({DATA_WIDTH{op_sltu      }} & sltu_result)
 	    			  | ({DATA_WIDTH{op_and       }} & and_result)
 	    			  | ({DATA_WIDTH{op_or        }} & or_result)
 	    			  | ({DATA_WIDTH{op_xor       }} & xor_result)
 	    			  | ({DATA_WIDTH{op_lui       }} & lui_result)
 	    			  | ({DATA_WIDTH{op_sll       }} & sll_result)
 	    			  | ({DATA_WIDTH{op_srl|op_sra}} & sr_result);
endmodule

module LSU_SRAM #(
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
  	assign arready = 1'b1; //总是可以接受读请求
	assign awready = 1'b1; //总是可以接受写请求

	reg [ADDR_WIDTH - 1 : 0] reg_araddr;

	reg [3:0] delay_cnt;
	reg pending_read;

	wire [3:0] rand_delay;
	lfsr4 lfsr(.clk(clk), .rst(rst), .rnd(rand_delay));

	// 通过 DPI-C 从内存读
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] vaddr_read(input bit[ADDR_WIDTH - 1 : 0] raddr,input bit[DATA_WIDTH - 1 : 0] len);
  	always @(posedge clk) begin
   		if(rst) begin
      		rvalid <= 1'b0;
			pending_read <= 1'b0;
		end else begin
			if(arvalid && arready && ~pending_read) begin
				reg_araddr <= araddr;

				delay_cnt <= rand_delay % 8;
				pending_read <= 'b1;
			end else if(pending_read) begin 
				if(delay_cnt == 'b0) begin
					pending_read <= 'b0;
   		   			rdata <= vaddr_read(reg_araddr, 'h4); //不支持rlen 那么就直接读4B
   	 	  			rvalid <= 1'b1;
   	  	 			rresp <= 2'b0;
				end else delay_cnt <= delay_cnt - 'b1;
			end
			if(rvalid && rready) rvalid <= 'b0; //不应该放在else if中 因为可能会少复位rvalid
		end
  	end

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
				if(delay_cnt == 'b0) begin
					pending_write <= 1'b0;
					aw_regValid <= 1'b0;
					w_regValid <= 1'b0;
					vaddr_write(reg_awaddr, func_wlen, func_wdata);
					bvalid <= 1'b1;
					bresp <= 2'b0;
				end else delay_cnt <= delay_cnt - 'b1;
			end

			if(bvalid && bready) begin
				bvalid <= 1'b0;
			end
		end
	end
	
endmodule