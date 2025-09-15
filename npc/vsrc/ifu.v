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

  input wb_to_if_done,

  //ar  
  input  arready,
  output reg arvalid,
  output [3 : 0] arid,
  output [7 : 0] arlen,
  output [2 : 0] arsize,
  output [1 : 0] arburst,
  output [ADDR_WIDTH - 1 : 0] araddr,

  //r
  input  rvalid,
  output rready,
  input  rlast,
  input  [3 : 0] rid,
  input  [1 : 0] rresp,
  input  [DATA_WIDTH - 1 : 0] rdata
);

  // 当前PC寄存器
  reg [ADDR_WIDTH - 1 : 0] fetch_pc;
  reg fetch_valid;

  // 存储ID阶段发来的PC
  reg [31:0] next_pc;

  // IFU连接的AXI读端口信号
  assign arid = 'b0; // 取指id是0 访存是1
  assign arlen = 'h0; // 不做突发传输 一次transfer
  assign arsize = 'h2; // 每次请求4B 
  assign arburst = 'h0;
  assign araddr = fetch_pc;
  assign rready = rvalid;

  // AXI 额外控制 控制不要重复发请求
  reg send_request;

  // 接收新的 PC——nextpc可以更新到fetch_pc
  wire accept_new_pc = wb_to_if_done;

  // 当前流水级false或者id级准备好接收信息
  // 相较原来去掉了 wb_to_if_done 使得不会让if_to_id_valid一直保存到wb级 id级可以尽早无效
  // 但是这样就得缓存next_pc
  assign if_to_id_ready = !fetch_valid || id_to_if_ready;

  // fetch_valid已经用来表示IF级的有效与否了
  // 只有当正确返回数据时 才置位if_to_id_valid 错误的话继续请求
  assign if_to_id_valid = fetch_valid && rid == 'h0 && rvalid && rready && rlast && rresp == 'h0;

  always @(posedge clk) begin
    if (rst) begin
      arvalid <= 1'b0;
      `ifdef YSYXSOC
      fetch_pc <= 32'h2000_0000;
      `else 
      fetch_pc <= 32'h8000_0000;
      `endif
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
      if (rid == 'h0 && rvalid && rready && rlast) begin
        send_request <= 1'b0;
      end

      if(if_to_id_valid && id_to_if_ready) begin
        fetch_valid <= 1'b0;
      end
    end
  end


  assign if_to_id_bus = {fetch_pc,rdata};

endmodule
