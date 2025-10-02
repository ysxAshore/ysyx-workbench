`timescale 1ns / 10ps

// Refer to the data sheet for the flash instructions at
// https://www.winbond.com/hq/product/code-storage-flash-memory/serial-nor-flash/?__locale=zh

module flash (
  input  sck,
  input  ss,
  input  mosi,
  output miso
);
  wire reset = ss;

  typedef enum [1:0] { cmd_t, addr_t, data_t, err_t } state_t; // 主状态机 4状态
  reg [1:0]  state;											   // 状态机变量
  reg [7:0]  counter;										   // 计数器 记录目前接受了几个mosi
  reg [7:0]  cmd;                                              // 记录mosi传递的命令
  reg [23:0] addr;											   // 记录mosi传递的地址
  reg [31:0] data;                                             // 记录经过位转换之后的rdata 用于之后的miso

  wire ren = (state == addr_t) && (counter == 8'd23);		   //在读取地址且已经读到23位 然后利用这一次的mosi组合得到24位地址 减少一拍
  wire [31:0] raddr = {8'b0, addr[22:0], mosi};
  wire [31:0] rdata;
  flash_cmd flash_cmd_i(
    .clock(sck),
    .valid(ren),
    .cmd(cmd),
    .addr(raddr),
    .data(rdata)
  );

  always@(posedge sck or posedge reset) begin
    if (reset) state <= cmd_t;
    else begin
      case (state)
        cmd_t:  state <= (counter == 8'd7 ) ? addr_t : state;   // 8bit命令 省一拍
        addr_t: state <= (cmd     != 8'h3 ) ? err_t  :		    // 只接受读命令
                         (counter == 8'd23) ? data_t : state;   // 24bit地址 省一拍
        data_t: state <= state;

        default: begin
          state <= state;
          $fwrite(32'h80000002, "Assertion failed: Unsupported command `%xh`, only support `03h` read command\n", cmd);
          $fatal;
        end
      endcase
    end
  end

  always@(posedge sck or posedge reset) begin
    if (reset) counter <= 8'd0;
    else begin
      case (state)
        cmd_t:   counter <= (counter < 8'd7 ) ? counter + 8'd1 : 8'd0;
        addr_t:  counter <= (counter < 8'd23) ? counter + 8'd1 : 8'd0;
        default: counter <= counter + 8'd1;
      endcase
    end
  end

  // 上升沿采样
  always@(posedge sck or posedge reset) begin
    if (reset)               cmd <= 8'd0;
    else if (state == cmd_t) cmd <= { cmd[6:0], mosi };
  end

  // 上升沿采样
  always@(posedge sck or posedge reset) begin
    if (reset) addr <= 24'd0;
    else if (state == addr_t && counter < 8'd23)
      addr <= { addr[22:0], mosi };
  end

  // 上升沿发送
  wire [31:0] data_wire = rdata;
  always@(posedge sck or posedge reset) begin
    if (reset) data <= 32'd0;
    else if (state == data_t) begin
      data <= { {counter == 8'd0 ? data_wire : data}[30:0], 1'b0 };
    end
  end

  assign miso = ss ? 1'b1 : ({(state == data_t && counter == 8'd0) ? data_wire : data}[31]);

endmodule

import "DPI-C" function void flash_read(input int addr, output int data);

module flash_cmd(
  input             clock,
  input             valid,
  input       [7:0] cmd,
  input      [31:0] addr,
  output reg [31:0] data
);
  always@(posedge clock) begin
    if (valid)
      if (cmd == 8'h03) flash_read(addr, data);
      else begin
        $fwrite(32'h80000002, "Assertion failed: Unsupport command `%xh`, only support `03h` read command\n", cmd);
        $fatal;
      end
  end
endmodule
