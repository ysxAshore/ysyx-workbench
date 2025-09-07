module lsu #(REG_ADDR_WIDTH = 5, ADDR_WIDTH = 32, DATA_WIDTH = 32)(    
	input  clk,
	input  rst,

	input  exe_to_mem_valid,
	output mem_to_exe_ready,
	input  [DATA_WIDTH * 2 + REG_ADDR_WIDTH + 4 - 1 : 0] exe_to_mem_bus,

	output reg mem_to_wb_valid,
	input  wb_to_mem_ready,
	output [DATA_WIDTH + REG_ADDR_WIDTH + 1 - 1 : 0] mem_to_wb_bus
);

	reg	m_regW;
	reg [REG_ADDR_WIDTH - 1 : 0]m_regAddr;
	reg [DATA_WIDTH - 1 : 0]e2m_regData;
	reg [DATA_WIDTH - 1 : 0]m_load_data;
	reg	[2:0] m_load_inst;

	assign mem_to_exe_ready = ~mem_to_wb_valid || wb_to_mem_ready;

	always @(posedge clk) begin
		if(rst) begin
			mem_to_wb_valid <= 'b0;
			m_regW <= 'b0;
		end else if(exe_to_mem_valid && mem_to_exe_ready) begin
			m_regW <= exe_to_mem_bus[DATA_WIDTH * 2 + REG_ADDR_WIDTH + 3 : DATA_WIDTH * 2 + REG_ADDR_WIDTH + 3];
			m_regAddr <= exe_to_mem_bus[DATA_WIDTH * 2 + REG_ADDR_WIDTH + 3 - 1 : DATA_WIDTH * 2 + 3];
			e2m_regData <= exe_to_mem_bus[DATA_WIDTH * 2 + 3 - 1 : DATA_WIDTH + 3];
			m_load_inst <= exe_to_mem_bus[DATA_WIDTH + 3 - 1 : DATA_WIDTH];
			m_load_data <= exe_to_mem_bus[DATA_WIDTH - 1 : 0];

			mem_to_wb_valid <= 1'b1;
		end else if(wb_to_mem_ready && mem_to_wb_valid) 
			mem_to_wb_valid <= 1'b0;
	end
	
	wire [DATA_WIDTH - 1 : 0] m_regData = {DATA_WIDTH{m_load_inst == 3'h0}} & e2m_regData |
					      				  {DATA_WIDTH{m_load_inst == 3'h1}} & {{(DATA_WIDTH - 8){m_load_data[7]}},m_load_data[7:0]} |
					      				  {DATA_WIDTH{m_load_inst == 3'h2}} & {{(DATA_WIDTH - 16){m_load_data[15]}},m_load_data[15:0]} |
					      				  {DATA_WIDTH{m_load_inst == 3'h3}} & {{(DATA_WIDTH - 32){m_load_data[31]}},m_load_data[31:0]} |
					      				  {DATA_WIDTH{m_load_inst == 3'h4}} & {{(DATA_WIDTH - 8){1'b0}},m_load_data[7:0]} |
					      				  {DATA_WIDTH{m_load_inst == 3'h5}} & {{(DATA_WIDTH - 16){1'b0}},m_load_data[15:0]};

	assign mem_to_wb_bus = {
		m_regW,
		m_regAddr,
		m_regData
	};

endmodule