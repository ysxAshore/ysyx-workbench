module axi4lite_xbar #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32
)(
  input clk,
  input rst,

  // 来自 Arbiter 的 master 接口
  input                  arvalid,
  input  [ADDR_WIDTH-1:0]araddr,
  output                 arready,

  output                 rvalid,
  output [DATA_WIDTH-1:0]rdata,
  output [1:0]           rresp,
  input                  rready,

  input                  awvalid,
  input  [ADDR_WIDTH-1:0]awaddr,
  output                 awready,

  input                  wvalid,
  input  [DATA_WIDTH-1:0]wdata,
  input  [DATA_WIDTH-1:0]wstrb,
  output                 wready,

  output                 bvalid,
  output [1:0]           bresp,
  input                  bready,

  // 到 UART
  output                 uart_arvalid,
  output [ADDR_WIDTH-1:0]uart_araddr,
  input                  uart_arready,

  input                  uart_rvalid,
  input  [DATA_WIDTH-1:0]uart_rdata,
  input  [1:0]           uart_rresp,
  output                 uart_rready,

  output                 uart_awvalid,
  output [ADDR_WIDTH-1:0]uart_awaddr,
  input                  uart_awready,

  output                 uart_wvalid,
  output [DATA_WIDTH-1:0]uart_wdata,
  output [DATA_WIDTH-1:0]uart_wstrb,
  input                  uart_wready,

  input                  uart_bvalid,
  input  [1:0]            uart_bresp,
  output                 uart_bready,

  // 到 SRAM
  output                 sram_arvalid,
  output [ADDR_WIDTH-1:0]sram_araddr,
  input                  sram_arready,

  input                  sram_rvalid,
  input  [DATA_WIDTH-1:0]sram_rdata,
  input  [1:0]           sram_rresp,
  output                 sram_rready,

  output                 sram_awvalid,
  output [ADDR_WIDTH-1:0]sram_awaddr,
  input                  sram_awready,

  output                 sram_wvalid,
  output [DATA_WIDTH-1:0]sram_wdata,
  output [DATA_WIDTH-1:0]sram_wstrb,
  input                  sram_wready,

  input                  sram_bvalid,
  input  [1:0]           sram_bresp,
  output                 sram_bready
);
  reg is_uart_read;
  reg is_sram_read;
  
  assign arready = uart_arvalid ? uart_arready :
                   sram_arvalid ? sram_arready :
                   1'b0;
  assign uart_arvalid = arvalid && araddr >= 32'ha000_03f8 && araddr < 32'ha000_03fc;
  assign sram_arvalid = arvalid && !(araddr >= 32'ha000_03f8 && araddr < 32'ha000_03fc);
  assign uart_araddr = araddr;
  assign sram_araddr = araddr;
  
  assign rvalid = is_uart_read ? uart_rvalid :
                  is_sram_read ? sram_rvalid :
                  1'b0;
  assign rdata = is_uart_read ? uart_rdata :
                 is_sram_read ? sram_rdata :
                 'b0;

  assign rresp = is_uart_read ? uart_rresp :
                 is_sram_read ? sram_rresp :
                 2'h3;
  
  assign sram_rready = rready & is_sram_read;
  assign uart_rready = rready & is_uart_read;

  always @(posedge clk) begin
    if(~rst) begin
      is_uart_read <= 1'b0;
      is_sram_read <= 1'b0;
    end else begin
      if(arvalid && ~is_sram_read) begin
        is_sram_read <= !(araddr >= 32'ha000_03f8 && araddr < 32'ha000_03fc);    
      end 
      if(arvalid && ~is_uart_read) begin
        is_uart_read <= araddr >= 32'ha000_03f8 && araddr < 32'ha000_03fc;
      end
      if(uart_rvalid && uart_rready && is_uart_read) begin
        is_uart_read <= 1'b0;
      end
      if(sram_rvalid && sram_rready && is_sram_read) begin
        is_sram_read <= 1'b0;
      end
    end
  end

  reg is_uart_write;
  reg is_sram_write;
  always @(posedge clk) begin
    if(~rst) begin
      is_uart_write <= 1'b0;
      is_sram_write <= 1'b0;
    end else begin
      if(awvalid && ~is_sram_write) begin
        is_sram_write <= !(awaddr >= 32'ha000_03f8 && awaddr < 32'ha000_03fc);    
      end 
      if(awvalid && ~is_uart_write) begin
        is_uart_write <= awaddr >= 32'ha000_03f8 && awaddr < 32'ha000_03fc;
      end
      if(uart_bvalid && uart_bready && is_uart_write) begin
        is_uart_write <= 1'b0;
      end
      if(sram_bvalid && sram_bready && is_sram_write) begin
        is_sram_write <= 1'b0;
      end
    end
  end

  assign uart_awvalid = awvalid && awaddr >= 32'ha000_03f8 && awaddr < 32'ha000_03fc;
  assign sram_awvalid = awvalid && !(awaddr >= 32'ha000_03f8 && awaddr < 32'ha000_03fc);  
  assign uart_awaddr = awaddr;
  assign sram_awaddr = awaddr;
  assign awready = uart_awvalid ? uart_awready :
                   sram_awvalid ? sram_awready :
                   1'b0;

  assign uart_wvalid = is_uart_write & wvalid;
  assign sram_wvalid = is_sram_write & wvalid;
  assign uart_wdata = wdata;
  assign uart_wstrb = wstrb;
  assign sram_wdata = wdata;
  assign sram_wstrb = wstrb;
  assign wready = uart_wvalid ? uart_wready :
                  sram_wvalid ? sram_wready :
                  1'b0;
  
  assign bvalid = is_uart_write ? uart_bvalid :
                  is_sram_write ? sram_bvalid :
                  1'b0;
  assign bresp = is_uart_write ? uart_bresp :
                 is_sram_write ? sram_bresp :
                 2'h3;
  assign uart_bready = bready & is_uart_write;
  assign sram_bready = bready & is_sram_write;

endmodule