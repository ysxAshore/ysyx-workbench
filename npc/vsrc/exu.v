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
	reg [DATA_WIDTH - 1 : 0] aluSrc1;
	reg [DATA_WIDTH - 1 : 0] aluSrc2;
	reg [10 : 0] aluOp;
	reg d_regW;
	reg [REG_ADDR_WIDTH - 1 : 0] d_regAddr;
	reg [2 : 0] load_inst;
	reg [3 : 0] store_mask;
	reg [DATA_WIDTH - 1 : 0] store_data;

	reg exe_to_mem_valid_temp;

	assign exe_to_id_ready = ~exe_to_mem_valid || mem_to_exe_ready;
	always @(posedge clk) begin
		if(rst) begin
			aluOp <= 'b0;
			d_regW <= 'b0;
			load_inst <= 'b0;
			store_mask <= 'b0;
			exe_to_mem_valid_temp <= 'b0;
		end else if (id_to_exe_valid && exe_to_id_ready) begin
			aluOp <= id_to_exe_bus[DATA_WIDTH * 3 + REG_ADDR_WIDTH + 19 - 1 : DATA_WIDTH * 3 + REG_ADDR_WIDTH + 8];
			aluSrc1 <= id_to_exe_bus[DATA_WIDTH * 3 + REG_ADDR_WIDTH + 8 - 1 : DATA_WIDTH * 2 + REG_ADDR_WIDTH + 8];
			aluSrc2 <= id_to_exe_bus[DATA_WIDTH * 2 + REG_ADDR_WIDTH  + 8 - 1 : DATA_WIDTH + REG_ADDR_WIDTH + 8];
			d_regW <= id_to_exe_bus[DATA_WIDTH + REG_ADDR_WIDTH + 7 : DATA_WIDTH + REG_ADDR_WIDTH + 7];
			d_regAddr <= id_to_exe_bus[DATA_WIDTH + REG_ADDR_WIDTH + 7 - 1 : DATA_WIDTH + 7];
			load_inst <= id_to_exe_bus[DATA_WIDTH + 7 - 1 : DATA_WIDTH + 4];
			store_mask <= id_to_exe_bus[DATA_WIDTH + 4 - 1 : DATA_WIDTH];
			store_data <= id_to_exe_bus[DATA_WIDTH - 1 : 0];
			
			exe_to_mem_valid_temp <= 'b1;
		end else if(mem_to_exe_ready && exe_to_mem_valid) 
			exe_to_mem_valid_temp <= 'b0;
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
	wire [DATA_WIDTH - 1 : 0] wlen = store_mask == 'h1 ? 'h1 :
									 store_mask == 'h3 ? 'h2 :
									 'h4;
	wire [DATA_WIDTH - 1 : 0] wdata = store_mask == 'h1 ? {{(DATA_WIDTH - 8){1'b0}}, store_data[7:0]} :
									  store_mask == 'h3 ? {{(DATA_WIDTH - 16){1'b0}}, store_data[15:0]} :
									  store_data[31:0];
	wire rvalid;

	LSU_SRAM lsu_sram(
		.clk(clk),
		.ren(load_inst != 3'b0 && exe_to_mem_valid_temp),
		.rlen(rlen),
		.raddr(aluResult),
		.rdata(load_data),
		.rvalid(rvalid),
		.wen(store_mask != 4'b0 && exe_to_mem_valid_temp),
		.wlen(wlen),
		.waddr(aluResult),
		.wdata(wdata)
	);

	assign exe_to_mem_valid = load_inst != 'b0 ? rvalid && exe_to_mem_valid_temp : exe_to_mem_valid_temp;

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
  input  clk,
  input  ren,
  input  [ADDR_WIDTH - 1 : 0] raddr,
  input  [DATA_WIDTH - 1 : 0] rlen,
  output reg rvalid,
  output reg [DATA_WIDTH - 1 : 0] rdata,
  
  input  wen,
  input  [ADDR_WIDTH - 1 : 0] waddr,
  input  [DATA_WIDTH - 1 : 0] wlen,
  input  [DATA_WIDTH - 1 : 0] wdata
);
	//地址不用对齐 因为vaddr_read/write都是可以直接指针运算访问虚拟数组的
	//read:根据load_inst给定len,然后对应的数据都会放在返回值低位
	//write:根据e_store_mask给定len,写数据就是低位的
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] vaddr_read(input bit[ADDR_WIDTH - 1 : 0] raddr,input bit[DATA_WIDTH - 1 : 0] len);
	import "DPI-C" function void vaddr_write(input bit[ADDR_WIDTH - 1 : 0] waddr,input bit[DATA_WIDTH - 1 : 0] wlen,input bit[DATA_WIDTH - 1 : 0] wdata);
  	always @(posedge clk) begin
    	if(ren) begin //在复位无效后开始取指
      		rdata <=  vaddr_read(raddr, rlen);
			rvalid <= 'b1;
		end else 
			rvalid <= 'b0;
		if(wen) begin
			vaddr_write(waddr, wlen, wdata);
		end
  	end
endmodule