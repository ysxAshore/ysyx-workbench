// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
//`define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else

typedef enum logic [2:0] {
  IDLE,
  WRITE_TX,
  WRITE_SS,
  WRITE_DIV,
  WRITE_CTRL,
  WAIT_BSY,
  FINISH
} xip_state_t;

reg p_write;
reg [4:0] p_addr;
reg [3:0] p_strb;
reg [31:0] p_wdata;

reg [2:0] state;

// APB总线
// sel时请求信息有效
// enable时进入了ENABLE状态
wire is_flash_access = in_psel && in_paddr[31:28] == 4'h3; //0x3000_0000

wire spi_ready;
wire [31:0] spi_rdata;

assign in_pready = state == FINISH && spi_ready && in_penable;
assign in_prdata = spi_rdata;

always @(posedge clock) begin
	if(reset) state <= IDLE;
	else begin
		case (state)
			IDLE : begin
				if(is_flash_access) begin
					p_addr <= 5'h4;
					p_strb <= 4'hf;
					p_write <= 'b1;
					p_wdata <= 8'h03 << 24 | (in_paddr & 'hfffffc);
					if(spi_ready) state <= WRITE_TX;
				end else if(in_psel) state <= FINISH;
			end
			WRITE_TX : begin
				if(spi_ready) state <= WRITE_SS;
				p_addr <= 'h18;
				p_strb <= 'hf;
				p_write <= 'b1;
				p_wdata <= 'h1;
			end 
			WRITE_SS : begin
				if(spi_ready) state <= WRITE_DIV;
				p_addr <= 'h14;
				p_strb <= 'hf;
				p_write <= 'b1;
				p_wdata <= 'h1;
			end
			WRITE_DIV : begin
				if(spi_ready) state <= WRITE_CTRL;
				p_addr <= 'h10;
				p_strb <= 'hf;
				p_write <= 'b1;
				p_wdata <= 'h2140;
			end
			WRITE_CTRL : begin
				state <= WAIT_BSY;
				p_addr <= 'h10;
				p_write <= 'b0;
			end
			WAIT_BSY : begin
				if(spi_ready & spi_rdata[8] != 'b1) begin
					state <= FINISH;
					p_addr <= 'h0;
					p_write <= 'b1;
				end else begin
					p_addr <= 'h10;
					p_write <= 'b0;
				end
			end
			FINISH : 
				if(spi_ready)
					state <= IDLE;
			default: state <= IDLE;
		endcase
	end
end

spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i(is_flash_access ? p_addr : in_paddr[4:0]),
  .wb_dat_i(is_flash_access ? p_wdata : in_pwdata),
  .wb_dat_o(spi_rdata),
  .wb_sel_i(is_flash_access ? p_strb : in_pstrb),
  .wb_we_i (is_flash_access ? p_write : in_pwrite),
  .wb_stb_i(in_psel),
  .wb_cyc_i(in_penable),
  .wb_ack_o(spi_ready),
  .wb_err_o(in_pslverr),
  .wb_int_o(spi_irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

`endif // FAST_FLASH

endmodule
