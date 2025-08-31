module top(
	input 		  clock,
	input         reset,
	output [31:0] inst,
	output [31:0] dnpc,
	output [31:0] pc
);

	localparam ADDR_WIDTH = 32;
	localparam DATA_WIDTH = 32;
	localparam REG_ADDR_WIDTH = 5;

  	ifu #(
  	  .ADDR_WIDTH(ADDR_WIDTH),
  	  .DATA_WIDTH(DATA_WIDTH)
  	)if_stage(
		.clk(clock),
		.rst(reset),
		.fectch_pc(pc),
		.inst(inst),
		.dnpc(dnpc)
	);

	wire d_regW;
	wire w_regW;
	wire [10:0] aluOp;
	wire [DATA_WIDTH - 1 : 0] aluSrc1;
	wire [DATA_WIDTH - 1 : 0] aluSrc2;
	wire [DATA_WIDTH - 1 : 0] w_regData;
	wire [REG_ADDR_WIDTH - 1 : 0] w_regAddr;
	wire [REG_ADDR_WIDTH - 1 : 0] d_regAddr;

	wire [2:0] load_inst;
	wire [3:0] store_mask;
	wire [DATA_WIDTH - 1 : 0] store_data;

	idu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	)id_stage(
		.clk(clock),
		.rst(reset),
		.inst(inst),
		.pc(pc),
		.aluSrc1(aluSrc1),
		.aluSrc2(aluSrc2),
		.aluOp(aluOp),
		.d_regW(d_regW),
		.d_regAddr(d_regAddr),
		.w_regW(w_regW),
		.w_regAddr(w_regAddr),
		.w_regData(w_regData),
		.dnpc(dnpc),
		.load_inst(load_inst),
		.store_mask(store_mask),
		.store_data(store_data)
	);

	wire e_regW;
	wire [DATA_WIDTH - 1 : 0] e_regData;
	wire [REG_ADDR_WIDTH - 1 : 0] e_regAddr;
	
	wire [2:0] e_load_inst;
	wire [3:0] e_store_mask;
	wire [DATA_WIDTH - 1 : 0] e_store_data;

	exu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)exe_stage(
		.clk(clock),
		.aluSrc1(aluSrc1),
		.aluSrc2(aluSrc2),
		.aluOp(aluOp),
		.d_regW(d_regW),
		.d_regAddr(d_regAddr),
		.e_regW(e_regW),
		.e_regAddr(e_regAddr),
		.e_regData(e_regData),
		.load_inst(load_inst),
		.store_mask(store_mask),
		.store_data(store_data),
		.e_load_inst(e_load_inst),
		.e_store_mask(e_store_mask),
		.e_store_data(e_store_data)
	);

	wire m_regW;
	wire [DATA_WIDTH - 1 : 0] m_regData;
	wire [REG_ADDR_WIDTH - 1 : 0] m_regAddr;
	lsu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	)mem_stage(
		.clk(clock),
		.e_regW(e_regW),
		.e_regAddr(e_regAddr),
		.e_regData(e_regData),
		.m_regW(m_regW),
		.m_regAddr(m_regAddr),
		.m_regData(m_regData),
		.e_load_inst(e_load_inst),
		.e_store_mask(e_store_mask),
		.e_store_data(e_store_data)
	);

	wbu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)wb_stage(
		.m_regW(m_regW),
		.m_regAddr(m_regAddr),
		.m_regData(m_regData),
		.w_regW(w_regW),
		.w_regAddr(w_regAddr),
		.w_regData(w_regData)
	);
endmodule
