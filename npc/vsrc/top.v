module top(
	input 		  clock,
	input         reset,
	output [31:0] inst,
	output [31:0] dnpc,
	output [31:0] pc,
	output        update_dut
);

	localparam ADDR_WIDTH = 32;
	localparam DATA_WIDTH = 32;
	localparam REG_ADDR_WIDTH = 5;

	wire id_to_if_valid;
	wire if_to_id_ready;
	wire [DATA_WIDTH - 1 : 0]id_to_if_bus;
	wire if_to_id_valid;
	wire id_to_if_ready;
	wire wb_to_if_done;
	wire [DATA_WIDTH * 2 - 1 : 0] if_to_id_bus;

	assign dnpc = id_to_if_bus;
	assign {pc, inst} = if_to_id_bus;
	assign update_dut = id_to_if_valid & if_to_id_ready;

  	ifu #(
  	  .ADDR_WIDTH(ADDR_WIDTH),
  	  .DATA_WIDTH(DATA_WIDTH)
  	)if_stage(
		.clk(clock),
		.rst(reset),
		.id_to_if_bus(id_to_if_bus),
		.id_to_if_valid(id_to_if_valid),
		.if_to_id_ready(if_to_id_ready),
		.if_to_id_bus(if_to_id_bus),
		.if_to_id_valid(if_to_id_valid),
		.id_to_if_ready(id_to_if_ready),
		.wb_to_if_done(wb_to_if_done)
	);

	wire id_to_exe_valid;
	wire exe_to_id_ready;
	wire [DATA_WIDTH * 3 + REG_ADDR_WIDTH + 19 - 1 : 0] id_to_exe_bus;
	wire wb_to_id_valid;
	wire id_to_wb_ready;
	wire [DATA_WIDTH + REG_ADDR_WIDTH + 1 - 1 : 0] wb_to_id_bus;

	idu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	)id_stage(
		.clk(clock),
		.rst(reset),
		.id_to_if_bus(id_to_if_bus),
		.id_to_if_valid(id_to_if_valid),
		.if_to_id_ready(if_to_id_ready),
		.if_to_id_bus(if_to_id_bus),
		.if_to_id_valid(if_to_id_valid),
		.id_to_if_ready(id_to_if_ready),
		.id_to_exe_bus(id_to_exe_bus),
		.id_to_exe_valid(id_to_exe_valid),
		.exe_to_id_ready(exe_to_id_ready),
		.wb_to_id_bus(wb_to_id_bus),
		.wb_to_id_valid(wb_to_id_valid),
		.id_to_wb_ready(id_to_wb_ready)
	);

	wire exe_to_mem_valid;
	wire mem_to_exe_ready;
	wire [DATA_WIDTH * 2 + REG_ADDR_WIDTH + 4 - 1 : 0] exe_to_mem_bus;

	exu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)exe_stage(
		.clk(clock),
		.rst(reset),
		.id_to_exe_bus(id_to_exe_bus),
		.id_to_exe_valid(id_to_exe_valid),
		.exe_to_id_ready(exe_to_id_ready),
		.exe_to_mem_bus(exe_to_mem_bus),
		.exe_to_mem_valid(exe_to_mem_valid),
		.mem_to_exe_ready(mem_to_exe_ready)
	);

	wire mem_to_wb_valid;
	wire wb_to_mem_ready;
	wire [DATA_WIDTH + REG_ADDR_WIDTH + 1 - 1 : 0] mem_to_wb_bus;

	lsu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH)
	)mem_stage(
		.clk(clock),
		.rst(reset),
		.exe_to_mem_bus(exe_to_mem_bus),
		.exe_to_mem_valid(exe_to_mem_valid),
		.mem_to_exe_ready(mem_to_exe_ready),
		.mem_to_wb_bus(mem_to_wb_bus),
		.mem_to_wb_valid(mem_to_wb_valid),
		.wb_to_mem_ready(wb_to_mem_ready)
	);

	wbu #(
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	)wb_stage(
		.clk(clock),
		.rst(reset),
		.mem_to_wb_bus(mem_to_wb_bus),
		.mem_to_wb_valid(mem_to_wb_valid),
		.wb_to_mem_ready(wb_to_mem_ready),
		.wb_to_id_bus(wb_to_id_bus),
		.wb_to_id_valid(wb_to_id_valid),
		.id_to_wb_ready(id_to_wb_ready),
		.if_to_id_ready(if_to_id_ready),
		.wb_to_if_done(wb_to_if_done)
	);
endmodule
