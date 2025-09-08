module top(
	input 		  clock,
	input         reset,
	output reg [31:0] inst,
	output reg [31:0] dnpc,
	output reg [31:0] pc,
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

	always @(posedge clock) begin
		if(reset) begin
			pc <= 'h8000_0000;
		end else begin
			if(if_to_id_valid && id_to_if_ready) begin
				pc <= if_to_id_bus[DATA_WIDTH + ADDR_WIDTH - 1 : DATA_WIDTH];
				inst <= if_to_id_bus[DATA_WIDTH - 1 : 0];
			end 
			if(id_to_if_valid && if_to_id_ready) dnpc <= id_to_if_bus;
		end
	end

	assign update_dut = wb_to_if_done;

	wire                      ifu_arvalid;
	wire [ADDR_WIDTH - 1 : 0] ifu_araddr;
	wire                      ifu_arready;
	wire                      ifu_rvalid;
	wire [DATA_WIDTH - 1 : 0] ifu_rdata;
	wire [             1 : 0] ifu_rresp;
	wire                      ifu_rready;

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
		.wb_to_if_done(wb_to_if_done),
		.arvalid(ifu_arvalid),
		.araddr(ifu_araddr),
		.arready(ifu_arready),
		.rready(ifu_rready),
		.rresp(ifu_rresp),
		.rvalid(ifu_rvalid),
		.rdata(ifu_rdata)
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

	wire                      lsu_arvalid;
	wire [ADDR_WIDTH - 1 : 0] lsu_araddr;
	wire                      lsu_arready;
	wire                      lsu_rvalid;
	wire [DATA_WIDTH - 1 : 0] lsu_rdata;
	wire [             1 : 0] lsu_rresp;
	wire                      lsu_rready;
	wire                      lsu_awvalid;
	wire [ADDR_WIDTH - 1 : 0] lsu_awaddr;
	wire                      lsu_awready;
	wire                      lsu_wvalid;
	wire [DATA_WIDTH - 1 : 0] lsu_wdata;
	wire [DATA_WIDTH - 1 : 0] lsu_wstrb;		
	wire                      lsu_wready;
	wire                      lsu_bvalid;
	wire [             1 : 0] lsu_bresp;
	wire                      lsu_bready;

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
		.mem_to_exe_ready(mem_to_exe_ready),
		.arvalid(lsu_arvalid),
	  	.araddr(lsu_araddr),
	  	.arready(lsu_arready),
	  	.rready(lsu_rready),
	  	.rvalid(lsu_rvalid),
	  	.rresp(lsu_rresp),
	  	.rdata(lsu_rdata),
	  	.awvalid(lsu_awvalid),
	  	.awaddr(lsu_awaddr),
	  	.awready(lsu_awready),
	  	.wvalid(lsu_wvalid),
	  	.wstrb(lsu_wstrb),
	  	.wdata(lsu_wdata),
	  	.wready(lsu_wready),
	  	.bready(lsu_bready),
	  	.bvalid(lsu_bvalid),
	  	.bresp(lsu_bresp)
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

	//ar  
 	wire arvalid;
	wire arid;
 	wire [32 - 1 : 0] araddr;
 	wire arready;

 	//r
 	wire rready;
 	wire [1:0] rresp;
 	wire rvalid;
 	wire [DATA_WIDTH - 1 : 0] rdata;

 	//aw
 	wire awvalid;
 	wire [32 - 1 : 0] awaddr;
 	wire awready;

 	//w
 	wire wvalid;
 	wire [DATA_WIDTH - 1 : 0] wstrb;
 	wire [DATA_WIDTH - 1 : 0] wdata;
 	wire wready;

 	//b
 	wire bready;
 	wire bvalid;
 	wire [1:0] bresp;

	axi4lite_arbiter arbiter(
	    // 时钟/复位
	    .clk        (clock),
	    .rst        (reset),

	    .ifu_arvalid(ifu_arvalid),
	    .ifu_araddr (ifu_araddr),
	    .ifu_arready(ifu_arready),
	    .ifu_rvalid (ifu_rvalid),
	    .ifu_rdata  (ifu_rdata),
	    .ifu_rresp  (ifu_rresp),
	    .ifu_rready (ifu_rready),

	    .lsu_arvalid(lsu_arvalid),
	    .lsu_araddr (lsu_araddr),
	    .lsu_arready(lsu_arready),
	    .lsu_rvalid (lsu_rvalid),
	    .lsu_rdata  (lsu_rdata),
	    .lsu_rresp  (lsu_rresp),
	    .lsu_rready (lsu_rready),

	    .lsu_awvalid(lsu_awvalid),
	    .lsu_awaddr (lsu_awaddr),
	    .lsu_awready(lsu_awready),
	    .lsu_wvalid (lsu_wvalid),
	    .lsu_wdata  (lsu_wdata),
		.lsu_wstrb  (lsu_wstrb),
	    .lsu_wready (lsu_wready),
	    .lsu_bvalid (lsu_bvalid),      
	    .lsu_bresp  (lsu_bresp),
	    .lsu_bready (lsu_bready),

	    .arvalid    (arvalid),
		.arid       (arid),
	    .araddr     (araddr),
	    .arready    (arready),
	    .rvalid     (rvalid),
	    .rdata      (rdata),
	    .rresp      (rresp),
	    .rready     (rready),
	    .awvalid    (awvalid),
	    .awaddr     (awaddr),
	    .awready    (awready),
	    .wvalid     (wvalid),
	    .wdata      (wdata),
		.wstrb      (wstrb),
	    .wready     (wready),
	    .bvalid     (bvalid),
	    .bresp      (bresp),
	    .bready     (bready)
	);

	axi4lite_sram sram(
		.clk(clock),
		.rst(reset),
		.arvalid    (arvalid),
		.arid		(arid),
		.araddr     (araddr),
		.arready    (arready),
		.rvalid     (rvalid),
		.rdata      (rdata),
		.rresp      (rresp),
		.rready     (rready),
		.awvalid    (awvalid),
		.awaddr     (awaddr),
		.awready    (awready),
		.wvalid     (wvalid),
		.wdata      (wdata),
		.wstrb      (wstrb),
		.wready     (wready),
		.bvalid     (bvalid),
		.bresp      (bresp),
		.bready     (bready)

	);
endmodule
