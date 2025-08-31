module lsu #(REG_ADDR_WIDTH = 5, ADDR_WIDTH = 32, DATA_WIDTH = 32)(    
	input 							clk,
	input 							e_regW,
    input  [REG_ADDR_WIDTH - 1 : 0] e_regAddr,
    input  [DATA_WIDTH - 1     : 0] e_regData,
	input  [				 2 : 0] e_load_inst,
	input  [				 3 : 0] e_store_mask,
	input  [DATA_WIDTH - 1     : 0] e_store_data,
	
	output 							m_regW,
    output [REG_ADDR_WIDTH - 1 : 0] m_regAddr,
    output [DATA_WIDTH - 1     : 0] m_regData
);
	assign m_regW = e_regW;
	assign m_regAddr = e_regAddr;

	reg[DATA_WIDTH-1:0] load_data;
	
	//地址不用对齐 因为vaddr_read/write都是可以直接指针运算访问虚拟数组的
	//read:根据load_inst给定len,然后对应的数据都会放在返回值低位
	//write:根据e_store_mask给定len,写数据就是低位的
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] vaddr_read(input bit[ADDR_WIDTH - 1 : 0] raddr,input bit[DATA_WIDTH - 1 : 0] len);
	import "DPI-C" function void vaddr_write(input bit[ADDR_WIDTH - 1 : 0] waddr,input bit[DATA_WIDTH - 1 : 0] wlen,input bit[DATA_WIDTH - 1 : 0] wdata);
	always @(e_load_inst or e_store_data or e_regData or e_store_data or e_store_mask) begin
		if(e_load_inst != 3'b0) begin
			load_data = vaddr_read(e_regData, e_load_inst == 3'h1 || e_load_inst == 3'h4 ? 'h1 :
											e_load_inst == 3'h2 || e_load_inst == 3'h5 ? 'h2 :
											'h4);
		end else begin
			load_data = 'b0;
		end

		if(e_store_mask == 'h1) 
			vaddr_write(e_regData, 'h1, {{(DATA_WIDTH - 8){1'b0}}, e_store_data[7:0]});
		if(e_store_mask == 'h3) 
			vaddr_write(e_regData, 'h2, {{(DATA_WIDTH - 16){1'b0}}, e_store_data[15:0]});
		if(e_store_mask == 'hf) 
			vaddr_write(e_regData, 'h4, e_store_data[31:0]);
	end

	assign m_regData = {DATA_WIDTH{e_load_inst == 3'h0}} & e_regData |
					   {DATA_WIDTH{e_load_inst == 3'h1}} & {{(DATA_WIDTH - 8){load_data[7]}},load_data[7:0]} |
					   {DATA_WIDTH{e_load_inst == 3'h2}} & {{(DATA_WIDTH - 16){load_data[15]}},load_data[15:0]} |
					   {DATA_WIDTH{e_load_inst == 3'h3}} & {{(DATA_WIDTH - 32){load_data[31]}},load_data[31:0]} |
					   {DATA_WIDTH{e_load_inst == 3'h4}} & {{(DATA_WIDTH - 8){1'b0}},load_data[7:0]} |
					   {DATA_WIDTH{e_load_inst == 3'h5}} & {{(DATA_WIDTH - 16){1'b0}},load_data[15:0]};

endmodule