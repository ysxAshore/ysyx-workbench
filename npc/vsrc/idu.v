module idu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(
	input clk,
	input [31:0] inst,

	output [DATA_WIDTH-1:0] aluSrc1,
	output [DATA_WIDTH-1:0] aluSrc2,
	output [9:0] aluOp,
	output d_regW,
	output [REG_ADDR_WIDTH-1:0] d_regAddr,

	input w_regW,
	input [REG_ADDR_WIDTH-1:0] w_regAddr,
	input [DATA_WIDTH-1:0] w_regData
);
	//recognize the inst
	wire addi = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b000;
	wire ebreak = inst[31:0] == 32'h0010_0073;

	//categorize the inst
	/*
	000:TYPE_N
	001:TYPE_R
	010:TYPE_I
	011:TYPE_U
	100:TYPE_S
	101:TYPE_B
	110:TYPE_J	
   	*/
	wire TYPE_N = ebreak;
	wire TYPE_R;
	wire TYPE_I = addi;
	wire TYPE_U;
	wire TYPE_S;
	wire TYPE_B;
	wire TYPE_J;
	wire [2:0] inst_type;
	assign inst_type[0] = TYPE_R | TYPE_U | TYPE_B;
	assign inst_type[1] = TYPE_I | TYPE_U | TYPE_J;
	assign inst_type[2] = TYPE_S | TYPE_B | TYPE_J;

	//read data,include register data and imm data
	wire [DATA_WIDTH-1:0] regData1;
	wire [DATA_WIDTH-1:0] regData2;
	wire [4:0]rs1 = inst[19:15];
	wire [4:0]rs2 = inst[24:20];
	wire [4:0]rd = inst[11:7];
	wire [DATA_WIDTH-1:0]immI = {{(DATA_WIDTH-12){inst[31]}},inst[31:20]};
	wire [DATA_WIDTH-1:0]immU = {{(DATA_WIDTH-20){inst[31]}},inst[31:12]} << 12;
	wire [DATA_WIDTH-1:0]immJ = {{(DATA_WIDTH-21){inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};
	wire [DATA_WIDTH-1:0]immS = {{(DATA_WIDTH-12){inst[31]}},inst[31:25],inst[11:7]};
	wire [DATA_WIDTH-1:0]immB = {{(DATA_WIDTH-13){inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0}; 

	RegisterFile #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)regFile(
		.clk(clk),
		.wen(w_regW),
		.wdata(w_regData),
		.waddr(w_regAddr),
		.raddr1(rs1),
		.rdata1(regData1),
		.raddr2(rs2),
		.rdata2(regData2)
	);

	//decide the alu operands
	assign aluSrc1 = regData1;
	assign aluSrc2 = {DATA_WIDTH{inst_type == 3'b001}} & regData2 |
					 {DATA_WIDTH{inst_type == 3'b010}} & immI     |
					 {DATA_WIDTH{inst_type == 3'b011}} & immU     |
					 {DATA_WIDTH{inst_type == 3'b100}} & immS     |
					 {DATA_WIDTH{inst_type == 3'b101}} & immB     |
					 {DATA_WIDTH{inst_type == 3'b110}} & immJ;	

	//decide the alu op
	/*
		0: add
		1: sub
		2: slt
		3: sltu
		4: and
		5: or
		6: xor
		7: sll
		8: srl
		9: sra
	   10: lui
	*/
    assign aluOp[0] = addi; 
    
    //decide the write reg
	assign d_regW = inst_type == 3'b001 | inst_type == 3'b010 | inst_type == 3'b011 | inst_type == 3'b110;
	assign d_regAddr = rd;

	//DPI-C recongnize the ebreak ,then notice the sim terminate
	import "DPI-C" function void callEbreak();
	always@(posedge ebreak)begin
		callEbreak();
	end
endmodule

module RegisterFile #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32) (
  input clk,
  input wen,
  input [DATA_WIDTH-1:0] wdata,
  input [REG_ADDR_WIDTH-1:0] waddr,
  input [REG_ADDR_WIDTH-1:0] raddr1,
  output [DATA_WIDTH-1:0] rdata1,
  input [REG_ADDR_WIDTH-1:0] raddr2,
  output [DATA_WIDTH-1:0] rdata2
);
  reg [DATA_WIDTH-1:0] rf [2**REG_ADDR_WIDTH-1:0];
  always @(posedge clk) begin
    if (wen) rf[waddr] <= wdata;
  end

  assign rdata1 = raddr1 == 0 ? {DATA_WIDTH{1'b0}} : rf[raddr1];
  assign rdata2 = raddr2 == 0 ? {DATA_WIDTH{1'b0}} : rf[raddr2];

endmodule