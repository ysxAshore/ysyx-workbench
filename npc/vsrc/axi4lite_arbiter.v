module axi4lite_arbiter #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
  input clk,
  input rst,

  // IFU Master 接口
  input                       ifu_arvalid,
  input  [ADDR_WIDTH - 1 : 0] ifu_araddr,
  output                      ifu_arready,
  
  output                      ifu_rvalid,
  output [DATA_WIDTH - 1 : 0] ifu_rdata,
  output [             1 : 0] ifu_rresp,
  input                       ifu_rready,

  // LSU Master 接口
  input                       lsu_arvalid,
  input  [ADDR_WIDTH - 1 : 0] lsu_araddr,
  output                      lsu_arready,
  
  output                      lsu_rvalid,
  output [DATA_WIDTH - 1 : 0] lsu_rdata,
  output [             1 : 0] lsu_rresp,
  input                       lsu_rready,

  input                       lsu_awvalid,
  input  [ADDR_WIDTH - 1 : 0] lsu_awaddr,
  output                      lsu_awready,
  
  input                       lsu_wvalid,
  input  [DATA_WIDTH - 1 : 0] lsu_wdata,
  output [DATA_WIDTH - 1 : 0] lsu_wstrb,
  output                      lsu_wready,

  output                      lsu_bvalid,
  output [             1 : 0] lsu_bresp,
  input                       lsu_bready,

  // SRAM Slave 接口
  output                      arvalid,
  output                      arid,
  output [DATA_WIDTH - 1 : 0] araddr,
  input                       arready,

  input                       rvalid,
  input  [DATA_WIDTH - 1 : 0] rdata,
  output [             1 : 0] rresp,
  output                      rready,

  output                      awvalid,
  output [ADDR_WIDTH - 1 : 0] awaddr,
  input                       awready,
  
  output                      wvalid,
  output [DATA_WIDTH - 1 : 0] wdata,
  output [DATA_WIDTH - 1 : 0] wstrb,
  input                       wready,

  input                       bvalid,
  input  [             1 : 0] bresp,
  output                      bready

);
    // 用于记录当前仲裁成功的master
    // 00 no request
    // 01 ifu
    // 10 lsu_read
    reg [1:0] grant_state;

    always @(posedge clk) begin
        if(rst) begin
            grant_state <= 2'b0;
        end else begin
            if(ifu_arvalid && grant_state == 2'b0) begin
                grant_state <= 2'h1;
            end else if(lsu_arvalid && grant_state == 2'b0) begin
                grant_state <= 2'h2;
            end

            if(rvalid && ifu_rready && grant_state == 2'h1) begin
                grant_state <= 2'h0;
            end else if(rvalid && lsu_rready && grant_state == 2'h2) begin
                grant_state <= 2'h0;
            end
        end
    end

    assign arvalid = grant_state == 2'h1 ? ifu_arvalid :
                     grant_state == 2'h2 ? lsu_arvalid :
                     1'b0;
    
    assign araddr = grant_state == 2'h1 ? ifu_araddr :
                    grant_state == 2'h2 ? lsu_araddr :
                    'b0;
    
    assign arid = grant_state == 2'h2 ? 'b1 : 'b0;

    assign ifu_arready = grant_state == 2'h1 & arready;
    assign lsu_arready = grant_state == 2'h2 & arready;

    assign ifu_rvalid = grant_state == 2'h1 & rvalid;
    assign ifu_rdata = {DATA_WIDTH{grant_state == 2'h1}} & rdata;
    assign ifu_rresp = {2{grant_state == 2'h1}} & rresp;
    assign lsu_rvalid = grant_state == 2'h2 & rvalid;
    assign lsu_rdata = {DATA_WIDTH{grant_state == 2'h2}} & rdata;
    assign lsu_rresp = {2{grant_state == 2'h2}} & rresp;
    assign rready = grant_state == 2'h1 ? ifu_rready :
                    grant_state == 2'h2 ? lsu_rready :
                    1'b0;

    assign awvalid = lsu_awvalid;
    assign awaddr = lsu_awaddr;
    assign lsu_awready = awready;

    assign wvalid = lsu_wvalid;
    assign wdata = lsu_wdata;
    assign wstrb = lsu_wstrb;
    assign lsu_wready = wready;

    assign lsu_bvalid = bvalid;
    assign lsu_bresp = bresp;
    assign bready = lsu_bready;

endmodule