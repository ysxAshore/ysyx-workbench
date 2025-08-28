module idu #(REG_ADDR_WIDTH = 5, ADDR_WIDTH = 32, DATA_WIDTH = 32)(
	input 							clk,
	input [		ADDR_WIDTH - 1 : 0] pc,
	input [		DATA_WIDTH - 1 : 0] inst,

	output [	DATA_WIDTH - 1 : 0] aluSrc1,
	output [	DATA_WIDTH - 1 : 0] aluSrc2,
	output [				10 : 0] aluOp,
	output 							d_regW,
	output [REG_ADDR_WIDTH - 1 : 0] d_regAddr,

	output [				 2 : 0] load_inst,
	output [				 3 : 0] store_mask,
	output [    DATA_WIDTH - 1 : 0] store_data,

	input 							w_regW,
	input  [REG_ADDR_WIDTH - 1 : 0] w_regAddr,
	input  [    DATA_WIDTH - 1 : 0] w_regData,

	output [	DATA_WIDTH - 1 : 0] dnpc
);
	//recognize the inst
	wire lb     = inst[6:0] == 7'b0000011 && inst[14:12] == 3'b000;
	wire lh     = inst[6:0] == 7'b0000011 && inst[14:12] == 3'b001;
	wire lw     = inst[6:0] == 7'b0000011 && inst[14:12] == 3'b010;
	wire lbu    = inst[6:0] == 7'b0000011 && inst[14:12] == 3'b100;
	wire lhu    = inst[6:0] == 7'b0000011 && inst[14:12] == 3'b101;

	wire addi   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b000;
	wire slli   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b001 && inst[31:26] == 6'b0;
	wire slti   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b010;
	wire sltiu  = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b011;
	wire xori   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b100;
	wire srli   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b101 && inst[31:26] == 6'b0;
	wire srai   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b101 && inst[31:26] == 6'b010000;
	wire ori    = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b110;
	wire andi   = inst[6:0] == 7'b0010011 && inst[14:12] == 3'b111;

	wire auipc  = inst[6:0] == 7'b0010111;

	wire sb     = inst[6:0] == 7'b0100011 && inst[14:12] == 3'b000;
	wire sh     = inst[6:0] == 7'b0100011 && inst[14:12] == 3'b001;
	wire sw     = inst[6:0] == 7'b0100011 && inst[14:12] == 3'b010;

	wire add    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b000 && inst[31:25] == 7'b0;
	wire sub    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b000 && inst[31:25] == 7'b0100000;
	wire sll    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b001 && inst[31:25] == 7'b0;
	wire slt    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b010 && inst[31:25] == 7'b0;
	wire sltu   = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b011 && inst[31:25] == 7'b0;
	wire _xor   = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b100 && inst[31:25] == 7'b0;
	wire srl    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b101 && inst[31:25] == 7'b0;
	wire sra    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b101 && inst[31:25] == 7'b0100000;
	wire _or    = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b110 && inst[31:25] == 7'b0;
	wire _and   = inst[6:0] == 7'b0110011 && inst[14:12] == 3'b111 && inst[31:25] == 7'b0;

	wire lui    = inst[6:0] == 7'b0110111;

	wire beq    = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b000;
	wire bne    = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b001;
	wire blt    = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b100;
	wire bge    = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b101;
	wire bltu   = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b110;
	wire bgeu   = inst[6:0] == 7'b1100011 && inst[14:12] == 3'b111;

	wire jalr   = inst[6:0] == 7'b1100111 && inst[14:12] == 3'b000;
	wire jal    = inst[6:0] == 7'b1101111;

	wire ebreak = inst[31:0] == 32'h0010_0073;

	wire inv    = ~ ( lb | lh | lw | lbu | lhu | 
				  	  addi | slli | slti | sltiu | xori | srli | srai | ori | andi | 
    				  auipc | 
    				  sb | sh | sw | 
    				  add | sub | sll | slt | sltu | _xor | srl | sra | _or | _and | 
    				  lui | 
    				  beq | bne | blt | bge | bltu | bgeu | 
    				  jalr | jal | 
    				  ebreak );


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
	wire TYPE_R = add | sub | sll | slt | sltu | _xor | srl | sra | _or | _and;
	wire TYPE_I = lb | lh | lw | lbu | lhu | addi | slli | slti | sltiu | xori | srli | srai | andi | ori;
	wire TYPE_U = auipc | lui;
	wire TYPE_S = sb | sh | sw;
	wire TYPE_B = beq | bne | blt | bge | bltu | bgeu;
	wire TYPE_J = jalr | jal;
	wire [2:0] inst_type;
	assign inst_type[0] = TYPE_R | TYPE_U | TYPE_B;
	assign inst_type[1] = TYPE_I | TYPE_U | TYPE_J;
	assign inst_type[2] = TYPE_S | TYPE_B | TYPE_J;

	//read data,include register data and imm data
	wire [DATA_WIDTH-1:0] regData1;
	wire [DATA_WIDTH-1:0] regData2;
	wire [4:0]rs1 = ebreak ? 'ha : inst[19:15]; // ebreak时需要读ra寄存器获得返回值
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
	assign aluSrc1 = (auipc | jal | jalr ) ? pc : regData1;
	assign aluSrc2 = (jal | jalr) ? 'h4 : 
					 {DATA_WIDTH{inst_type == 3'b001}} & regData2 |
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
    assign aluOp[0]  = lb | lh | lw | lbu | lhu | addi | auipc | sb | sh | sw | add | jalr | jal;
	assign aluOp[1]  = sub;
	assign aluOp[2]  = slti  | slt;
	assign aluOp[3]  = sltiu | sltu;
	assign aluOp[4]  = andi  | _and;
	assign aluOp[5]  = ori   | _or;
	assign aluOp[6]  = xori  | _xor;
	assign aluOp[7]  = slli  | sll;
	assign aluOp[8]  = srli  | srl;
	assign aluOp[9]  = srai  | sra;
	assign aluOp[10] = lui;
    
    //decide the write reg
	assign d_regW = inst_type == 3'b001 | inst_type == 3'b010 | inst_type == 3'b011 | inst_type == 3'b110;
	assign d_regAddr = rd;

	//jump and branch inst
	wire [ADDR_WIDTH - 1 : 0] snpc = pc + 'h4;
	wire [ADDR_WIDTH - 1 : 0] branch_pc = pc + immB;
	wire [ADDR_WIDTH - 1 : 0] jalr_pc = (regData1 + immI) & ~'h3; //对齐
	wire [ADDR_WIDTH - 1 : 0] jal_pc = pc + immJ;
	wire taken_branch = beq & regData1 == regData2 |
						bne & regData1 != regData2 |
						blt & $signed(regData1) < $signed(regData2) |
						bltu & regData1 < regData2 |
						bge & ~($signed(regData1) < $signed(regData2)) |
						bgeu & ~(regData1 < regData2);
	assign dnpc = {32{jalr}} & jalr_pc |
				  {32{jal}}  & jal_pc  |
				  {32{taken_branch}} & branch_pc |
				  {32{~jal & ~jalr & ~taken_branch}} & snpc;
	
	//mem inst
	/*
		001 lb
		010 lh
		011 lw
		100 lbu
		101 lhu
	*/
	assign load_inst[0] = lb | lw | lhu;
	assign load_inst[1] = lh | lw;
	assign load_inst[2] = lbu | lhu;
	assign store_mask[0] = sw | sh | sb;
	assign store_mask[1] = sw | sh;
	assign store_mask[2] = sw;
	assign store_mask[3] = sw;
	assign store_data = regData2;

	//DPI-C recongnize the ebreak ,then notice the sim terminate
	import "DPI-C" function void callEbreak(input bit[DATA_WIDTH - 1 : 0] retval, input bit[ADDR_WIDTH - 1 : 0] pc);
	always@(clk)begin //在ebreak上升沿时 pc和regData1都是上个指令的 因此需要在下降沿
		if(ebreak)
			callEbreak(regData1,pc);
	end
endmodule

module RegisterFile #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32) (
  input 						 clk,
  input 						 wen,
  input  [DATA_WIDTH - 1    : 0] wdata,
  input  [REG_ADDR_WIDTH -1 : 0] waddr,
  input  [REG_ADDR_WIDTH -1 : 0] raddr1,
  output [DATA_WIDTH     -1 : 0] rdata1,
  input  [REG_ADDR_WIDTH -1 : 0] raddr2,
  output [DATA_WIDTH     -1 : 0] rdata2
);
  reg [DATA_WIDTH - 1 : 0] rf [1 << REG_ADDR_WIDTH - 1 : 0];
  always @(posedge clk) begin
    if (wen) rf[waddr] <= wdata;
  end

  assign rdata1 = raddr1 == 0 ? 'b0 : rf[raddr1];
  assign rdata2 = raddr2 == 0 ? 'b0 : rf[raddr2];

endmodule