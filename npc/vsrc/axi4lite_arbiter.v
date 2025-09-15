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
  input  [			   3 : 0] ifu_arid,
  input  [             7 : 0] ifu_arlen,
  input  [             2 : 0] ifu_arsize,
  input  [             1 : 0] ifu_arburst,
  output                      ifu_rlast,
  output [             3 : 0] ifu_rid,

  // LSU Master 接口
  input                       lsu_arvalid,
  input  [ADDR_WIDTH - 1 : 0] lsu_araddr,
  output                      lsu_arready,
  
  output                      lsu_rvalid,
  output [DATA_WIDTH - 1 : 0] lsu_rdata,
  output [             1 : 0] lsu_rresp,
  input                       lsu_rready,
  input  [			   3 : 0] lsu_arid,
  input  [             7 : 0] lsu_arlen,
  input  [             2 : 0] lsu_arsize,
  input  [             1 : 0] lsu_arburst,
  output                      lsu_rlast,
  output [             3 : 0] lsu_rid,

  input                       lsu_awvalid,
  input  [ADDR_WIDTH - 1 : 0] lsu_awaddr,
  output                      lsu_awready,
  input  [             3 : 0] lsu_awid,
  input  [             7 : 0] lsu_awlen,
  input  [             2 : 0] lsu_awsize,
  input  [             1 : 0] lsu_awburst,
  
  input                       lsu_wvalid,
  input  [DATA_WIDTH - 1 : 0] lsu_wdata,
  output [             3 : 0] lsu_wstrb,
  output                      lsu_wready,
  input  					  lsu_wlast,

  output                      lsu_bvalid,
  output [             1 : 0] lsu_bresp,
  input                       lsu_bready,
  output [ 			   3 : 0] lsu_bid,

  // SRAM Slave 接口
  output                      arvalid,
  output [DATA_WIDTH - 1 : 0] araddr,
  output [             3 : 0] arid,
  output [             7 : 0] arlen,
  output [             2 : 0] arsize,
  output [             1 : 0] arburst,
  input                       arready,

  input                       rvalid,
  input  [DATA_WIDTH - 1 : 0] rdata,
  input  [             1 : 0] rresp,
  output                      rready,
  input                       rlast,
  input  [             3 : 0] rid,

  output                      awvalid,
  output [ADDR_WIDTH - 1 : 0] awaddr,
  input                       awready,
  output [             3 : 0] awid,
  output [             7 : 0] awlen,
  output [             2 : 0] awsize,
  output [             1 : 0] awburst,
  
  output                      wvalid,
  output [DATA_WIDTH - 1 : 0] wdata,
  output [             3 : 0] wstrb,
  output                      wlast,
  input                       wready,

  input                       bvalid,
  input  [             1 : 0] bresp,
  input  [             3 : 0] bid,
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
    
    assign arid = grant_state == 2'h1 ? ifu_arid :
                  grant_state == 2'h2 ? lsu_arid :
                  4'b0;
    
    assign arlen = grant_state == 2'h1 ? ifu_arlen :
                   grant_state == 2'h2 ? lsu_arlen :
                   8'h0;
    
    assign arsize = grant_state == 2'h1 ? ifu_arsize :
                    grant_state == 2'h2 ? lsu_arsize :
                    3'h0;

    assign arburst = grant_state == 2'h1 ? ifu_arburst :
                     grant_state == 2'h2 ? lsu_arburst :
                     2'b0;

    assign ifu_arready = grant_state == 2'h1 & arready;
    assign lsu_arready = grant_state == 2'h2 & arready;

    assign ifu_rvalid = grant_state == 2'h1 & rvalid;
    assign ifu_rdata = {DATA_WIDTH{grant_state == 2'h1}} & rdata;
    assign ifu_rresp = {2{grant_state == 2'h1}} & rresp;
    assign lsu_rvalid = grant_state == 2'h2 & rvalid;
    assign lsu_rdata = {DATA_WIDTH{grant_state == 2'h2}} & rdata;
    assign lsu_rresp = {2{grant_state == 2'h2}} & rresp;
    assign ifu_rlast = grant_state == 2'h1 & rlast;
    assign lsu_rlast = grant_state == 2'h2 & rlast;
    assign ifu_rid = {4{grant_state == 2'h1}} & rid;
    assign lsu_rid = {4{grant_state == 2'h2}} & rid;
    assign rready = grant_state == 2'h1 ? ifu_rready :
                    grant_state == 2'h2 ? lsu_rready :
                    1'b0;

    assign awvalid = lsu_awvalid;
    assign awaddr = lsu_awaddr;
    assign awid = lsu_awid;
    assign awlen = lsu_awlen;
    assign awsize = lsu_awsize;
    assign awburst = lsu_awburst;
    assign lsu_awready = awready;

    assign wvalid = lsu_wvalid;
    assign wdata = lsu_wdata;
    assign wstrb = lsu_wstrb;
    assign wlast = lsu_wlast;
    assign lsu_wready = wready;

    assign lsu_bvalid = bvalid;
    assign lsu_bresp = bresp;
    assign lsu_bid = bid;
    assign bready = lsu_bready;

endmodule