module exu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(
	input clk,
	input [DATA_WIDTH-1:0] aluSrc1,
	input [DATA_WIDTH-1:0] aluSrc2,
	input [9:0] aluOp,
	input d_regW,
	input [REG_ADDR_WIDTH-1:0] d_regAddr,

	output e_regW,
	output [REG_ADDR_WIDTH-1:0]e_regAddr,
	output [DATA_WIDTH-1:0]e_regData

);
	
	wire [DATA_WIDTH-1:0] aluResult;
	alu #(
		.DATA_WIDTH(DATA_WIDTH)
	) exe_alu(
		.aluOp(aluOp),
		.aluSrc1(aluSrc1),
		.aluSrc2(aluSrc2),
		.aluResult(aluResult)
	);
	assign e_regW = d_regW;
	assign e_regAddr = d_regAddr;
	assign e_regData = aluResult;
endmodule

module alu #(DATA_WIDTH = 32)(
	input [9:0] aluOp,
	input [DATA_WIDTH-1:0] aluSrc1,
	input [DATA_WIDTH-1:0] aluSrc2,
	output [DATA_WIDTH-1:0] aluResult	
);
	wire add_op = aluOp[0];
	
	wire [DATA_WIDTH-1:0] addResult;
	assign addResult = aluSrc1 + aluSrc2;

	assign aluResult = {DATA_WIDTH{add_op}} & addResult;

endmodule