module wbu #(REG_ADDR_WIDTH = 5, DATA_WIDTH = 32)(    
	input clk,
	input rst,

	input  mem_to_wb_valid,
	output wb_to_mem_ready,
	input  [DATA_WIDTH + REG_ADDR_WIDTH + 1 - 1 : 0] mem_to_wb_bus,

	input  id_to_wb_ready,
	output wb_to_id_valid,
	output [DATA_WIDTH + REG_ADDR_WIDTH + 1 - 1 : 0] wb_to_id_bus,

	input  if_to_id_ready,
	output wb_to_if_done
);
	reg wb_valid;

	reg w_regW;
	reg [REG_ADDR_WIDTH - 1 : 0] w_regAddr;
	reg [DATA_WIDTH - 1 : 0] w_regData;

	always @(posedge clk) begin
		if(rst) begin
			wb_valid <= 'b0;
		end else if(mem_to_wb_valid && wb_to_mem_ready) begin
			w_regW <= mem_to_wb_bus[DATA_WIDTH + REG_ADDR_WIDTH : DATA_WIDTH + REG_ADDR_WIDTH];
			w_regAddr <= mem_to_wb_bus[DATA_WIDTH + REG_ADDR_WIDTH - 1 : DATA_WIDTH];
			w_regData <= mem_to_wb_bus[DATA_WIDTH - 1 : 0];

			wb_valid <= 'b1;
		end else begin
			//不用考虑wb_to_if_done 因为给过去会立即更新nextpc为pc
			if(wb_to_id_valid && id_to_wb_ready)
				wb_valid <= 'b0;
		end
	end

	assign wb_to_mem_ready = ~wb_valid || id_to_wb_ready;
	assign wb_to_if_done = wb_valid;
	assign wb_to_id_valid = wb_valid;

	assign wb_to_id_bus = {
		w_regData,
		w_regAddr,
		w_regW
	};
endmodule