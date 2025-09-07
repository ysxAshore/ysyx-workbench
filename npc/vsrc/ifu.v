module ifu #(parameter DATA_WIDTH = 32, parameter ADDR_WIDTH = 32)(
  input clk,
  input rst,

  //ID2IF Bus 
  input [DATA_WIDTH - 1 : 0] id_to_if_bus, //dnpc
  input        id_to_if_valid,
  output       if_to_id_ready,

  //IF2ID Bus
  output [DATA_WIDTH + ADDR_WIDTH - 1 : 0] if_to_id_bus,//pc+inst
  output            if_to_id_valid,
  input             id_to_if_ready,

  input wb_to_if_done
);

  // 当前PC寄存器
  reg [ADDR_WIDTH - 1 : 0] fetch_pc;
  reg fetch_valid;

  // 存储ID阶段发来的PC
  reg [31:0] next_pc;

  // IFU内部连接SRAM的AXI读端口信号
  reg arvalid;
  wire arready;
  wire rready = rvalid;
  wire rvalid;
  wire [1:0] rresp;
  wire [DATA_WIDTH-1:0] rdata;

  // AXI 额外控制 控制不要重复发请求
  reg send_request;

  // 接收新的 PC——nextpc可以更新到fetch_pc
  wire accept_new_pc = wb_to_if_done;

  // 当前流水级false或者id级准备好接收信息
  // 相较原来去掉了 wb_to_if_done 使得不会让if_to_id_valid一直保存到wb级 id级可以尽早无效
  // 但是这样就得缓存next_pc
  assign if_to_id_ready = !fetch_valid || id_to_if_ready;

  // fetch_valid已经用来表示IF级的有效与否了
  assign if_to_id_valid = fetch_valid && rvalid && rready;

  always @(posedge clk) begin
    if (rst) begin
      arvalid <= 1'b0;
      fetch_pc <= 32'h8000_0000;
      fetch_valid <= 1'b1;
      send_request <= 1'b0;
    end else begin
      // 接收来自 ID 阶段的新 PC
      if (accept_new_pc) begin
        fetch_pc <= next_pc;
        fetch_valid <= 1'b1;
      end

      if(id_to_if_valid && if_to_id_ready) begin
        next_pc <= id_to_if_bus;
      end

      // 发出 arvalid，只在“需要发请求 + 没发过请求”时，发起 arvalid
      // 这里|accept_new_pc 可以节省一周期 在更新fetch_pc的同时发出请求
      if ((fetch_valid | accept_new_pc) && !arvalid && ~send_request) begin
        arvalid <= 1'b1;
        send_request <= 1'b1;
      end else if (arvalid && arready) begin
        arvalid <= 1'b0; //ar握手后撤销
      end

      // 接收 rvalid 数据 
      if (rvalid && rready) begin
        send_request <= 1'b0;
      end

      if(if_to_id_valid && id_to_if_ready) begin
        fetch_valid <= 1'b0;
      end
    end
  end


  assign if_to_id_bus = {fetch_pc,rdata};

  IFU_SRAM ifu_sram (
    .clk(clk),
    .rst(rst),
    .arvalid(arvalid),
    .araddr(fetch_pc),
    .arready(arready),
    .rready(rready),
    .rvalid(rvalid),
    .rresp(rresp),
    .rdata(rdata),
    .awvalid(1'b0), // 未使用写通道
    .awaddr(32'b0),
    .awready(),
    .wvalid(1'b0),
    .wstrb(4'b0),
    .wdata(32'b0),
    .wready(),
    .bready(1'b0),
    .bvalid(),
    .bresp()
  );

endmodule

module IFU_SRAM #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32
)(
  input clk,
  input rst,
  
  //ar  
  input arvalid,
  input [ADDR_WIDTH - 1 : 0] araddr,
  output arready,

  //r
  input rready,
  output reg [1:0] rresp,
  output reg rvalid,
  output reg [DATA_WIDTH - 1 : 0] rdata,

  //aw
  input awvalid,
  input [ADDR_WIDTH - 1 : 0] awaddr,
  output awready,

  //w
  input wvalid,
  input [3:0] wstrb,
  input [DATA_WIDTH - 1 : 0] wdata,
  output wready,

  //b
  input bready,
  output reg bvalid,
  output reg [1:0] bresp
);
  assign arready = 1'b1;

  wire [3:0] rand_delay;
  lfsr4 lfsr(.clk(clk), .rst(rst), .rnd(rand_delay));

  reg [ADDR_WIDTH - 1 : 0] reg_araddr;

  reg [3:0] delay_cnt;
  reg pending; 

  // 通过 DPI-C 从内存读指令 只用实现AR、R通道 其他忽略
	import "DPI-C" function bit[DATA_WIDTH - 1 : 0] inst_fetch(input bit[ADDR_WIDTH - 1 : 0] raddr);
  always @(posedge clk) begin
    if(rst) begin
      rvalid <= 1'b0;
      pending <= 1'b0;
    end else begin
      if(arvalid && arready && ~pending) begin
        reg_araddr <= araddr;
        delay_cnt <= rand_delay % 8;
        pending <= 1'b1;
      end else if(pending) begin
        if(delay_cnt == 'h0) begin
          pending <= 1'b0;
          rvalid <= 1'b1;
          rdata <= inst_fetch(reg_araddr);
          rresp <= 2'b0;
        end else delay_cnt <= delay_cnt - 'b1;
      end
      if(rvalid && rready) begin
        rvalid <= 1'b0;
      end
    end
  end
endmodule

module lfsr4(
  input clk,
  input rst,
  output reg [3:0] rnd
);
  always @(posedge clk or negedge rst) begin
    if (!rst) rnd <= 4'hF; // 初始值不能为 0
    else rnd <= {rnd[2:0], rnd[3] ^ rnd[2]};
  end
endmodule