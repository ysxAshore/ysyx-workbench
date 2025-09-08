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
  output reg arvalid,
  output [ADDR_WIDTH - 1 : 0] araddr,
  input  arready,

  //r
  output rready,
  input  [1:0] rresp,
  input  rvalid,
  input  [DATA_WIDTH - 1 : 0] rdata
);

  // 当前PC寄存器
  reg [ADDR_WIDTH - 1 : 0] fetch_pc;
  reg fetch_valid;

  // 存储ID阶段发来的PC
  reg [31:0] next_pc;

  // IFU连接的AXI读端口信号
  assign rready = rvalid;
  assign araddr = fetch_pc;

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

endmodule
