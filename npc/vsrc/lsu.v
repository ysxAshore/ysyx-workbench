module lsu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(    
	input clk,
	input e_regW,
    input [REG_ADDR_WIDTH-1:0]e_regAddr,
    input [DATA_WIDTH-1:0]e_regData,

	output m_regW,
    output [REG_ADDR_WIDTH-1:0]m_regAddr,
    output [DATA_WIDTH-1:0]m_regData
);
	assign m_regW = e_regW;
	assign m_regAddr = e_regAddr;
	assign m_regData = e_regData;	
endmodule