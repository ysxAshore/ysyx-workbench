module wbu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(    
	input m_regW,
    input [REG_ADDR_WIDTH-1:0]m_regAddr,
    input [DATA_WIDTH-1:0]m_regData,
	
	output w_regW,
    output [REG_ADDR_WIDTH-1:0]w_regAddr,
    output [DATA_WIDTH-1:0]w_regData
);
	
	assign w_regW = m_regW;
	assign w_regAddr = m_regAddr;
	assign w_regData = m_regData;	
endmodule