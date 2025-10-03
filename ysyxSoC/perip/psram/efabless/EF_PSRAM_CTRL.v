/*
	Copyright 2020 Efabless Corp.

	Author: Mohamed Shalan (mshalan@efabless.com)

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at:
	http://www.apache.org/licenses/LICENSE-2.0
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/
/*
    QSPI PSRAM Controller

    Pseudostatic RAM (PSRAM) is DRAM combined with a self-refresh circuit.
    It appears externally as slower SRAM, albeit with a density/cost advantage
    over true SRAM, and without the access complexity of DRAM.

    The controller was designed after https://www.issi.com/WW/pdf/66-67WVS4M8ALL-BLL.pdf
    utilizing both EBh and 38h commands for reading and writting.

    Benchmark data collected using CM0 CPU when memory is PSRAM only

        Benchmark       PSRAM (us)  1-cycle SRAM (us)   Slow-down
        ---------       ----------  -----------------   ---------
        xtea            840         212                 3.94
        stress          1607        446                 3.6
        hash            5340        1281                4.16
        chacha          2814        320                 8.8
        aes sbox        2370        322                 7.3
        nqueens         3496        459                 7.6
        mtrans          2171        2034                1.06
        rle             903         155                 5.8
        prime           549         97                  5.66
*/

`timescale              1ns/1ps
`default_nettype        none

module PSRAM_RESET_CMD (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            valid,
    output  wire            done,

    output  reg             sck,
    output  reg             ce_n,
    output  wire [3:0]      dout,
    output  wire            douten
);
    // 两种状态
    localparam  IDLE = 1'b0,
                SEND_CMD = 1'b1;

    wire [7:0]  FINAL_COUNT = 7; //只需要发送8bit command

    reg         state;
    reg [7:0]   counter;

    wire[7:0]   CMD_01H = 8'h01; //当PSRAM收到该命令时 表示从(1-4-4)进入(4-4-4)module

    // FSM
    always @ (posedge clk or negedge rst_n)
        if(!rst_n) state <= IDLE;
        else begin
            case (state)
                IDLE: if(valid) state <= SEND_CMD;
                SEND_CMD: if(done) state <= IDLE;
            endcase
        end

    // 在clk的每次上升沿周期时 变化sck 也就是将clk二分频作为sck
    // sck只有在ce_n有效时才会 升降处理
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            sck <= 1'b0;
        else if(~ce_n)
            sck <= ~ sck;
        else if(state == IDLE)
            sck <= 1'b0;

    // ce_n低电平有效 用于使能对应设备
    // 当主状态机进入到 READ 状态时会 使能ce_n， 即存在有效请求时使能设备
    // ce_n有效以后的下一个时钟周期 会开始变化sck
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            ce_n <= 1'b1;
        else if(state == SEND_CMD)
            ce_n <= 1'b0;
        else
            ce_n <= 1'b1;

    // 计数 用于记录经过了多少个SCK sck下降沿计数
    // 为什么是下降沿 因为在ce_n有效时clk的上升沿会变化sck
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            counter <= 8'b0;
        else if(sck & ~done)
            counter <= counter + 1'b1;
        else if(state == IDLE)
            counter <= 8'b0;

    // counter < 8: 发送命令 命令是按照1bit发送的 先发送MSB
    // counter 8~13: 发送地址 地址是按照4bit发送的 也是发送MSB
    assign dout     =   (counter < 8)   ?   {3'b0, CMD_01H[7 - counter]}:
                        4'h0;

    // counter< 8时 是向psram发送 cmd
    assign douten   = (counter < 8);

    // counter == 8时 说明 命令已发完
    assign done     = (counter == FINAL_COUNT+1);

endmodule

//USING EBH Command
module PSRAM_READER (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            qpi_enable,
    input   wire [23:0]     addr,
    input   wire            rd,
    input   wire [2:0]      size,
    output  wire            done,
    output  wire [31:0]     line,

    output  reg             sck,
    output  reg             ce_n,
    input   wire [3:0]      din,
    output  wire [3:0]      dout,
    output  wire            douten
);

    // 两种状态
    localparam  IDLE = 1'b0,
                READ = 1'b1;

    // READ 使用1-4-4 8cycle:cmd 24/2cycle:addr size:width/8->size width/4->cycle size*2cycle
    // 而因为 READ 时 size 总是4 -> 需要 19 + 4 * 2 = 27cycle
    // qpi fast mode 时 传输cmd由8减为2
    wire [7:0]  FINAL_COUNT = qpi_enable ? 13 + size * 2 : 19 + size * 2; // was 27: Always read 1 word

    reg         state, nstate;
    reg [7:0]   counter;
    reg [23:0]  saddr;
    reg [7:0]   data [3:0];

    wire[7:0]   CMD_EBH = 8'heb;

    always @*
        case (state)
            IDLE: if(rd) nstate = READ; else nstate = IDLE;
            READ: if(done) nstate = IDLE; else nstate = READ;
        endcase

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) state <= IDLE;
        else state <= nstate;

    // 在clk的每次上升沿周期时 变化sck 也就是将clk二分频作为sck
    // sck只有在ce_n有效时才会 升降处理
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            sck <= 1'b0;
        else if(~ce_n)
            sck <= ~ sck;
        else if(state == IDLE)
            sck <= 1'b0;

    // ce_n低电平有效 用于使能对应设备
    // 当主状态机进入到 READ 状态时会 使能ce_n， 即存在有效请求时使能设备
    // ce_n有效以后的下一个时钟周期 会开始变化sck
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            ce_n <= 1'b1;
        else if(state == READ)
            ce_n <= 1'b0;
        else
            ce_n <= 1'b1;

    // 计数 用于记录经过了多少个SCK sck下降沿计数
    // 为什么是下降沿 因为在ce_n有效时clk的上升沿会变化sck
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            counter <= 8'b0;
        else if(sck & ~done)
            counter <= counter + 1'b1;
        else if(state == IDLE)
            counter <= 8'b0;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            saddr <= 24'b0;
        else if((state == IDLE) && rd)
            //saddr <= {addr[23:2], 2'b0};
            saddr <= {addr[23:0]};

    // Sample with the negedge of sck
    // sck上升沿发送 下降沿采样
    // 开始接收时counter就是 8'b00010100 ~ 8'b00011011
    //         那么counter[7:1]就是8'd10 8'd10 8'd11 8'd11 8'd12 8'd12 8'd13 8'd13
    // 每次存data[0]的8bit data[1]的8bit ...
    // 也就是说接收8个sck 从低字节接收 每次先接收字节内的高4bit
    // qpi-mode时 14 15 16 17 18 19 20 21 8'b00001110 
    //            8'd7 8'd7 8'd8 8'd8 8'd9 8'd9 8'd10 8'd10
    wire[1:0] byte_index = qpi_enable ? {counter[7:1] - 8'd7}[1:0] : {counter[7:1] - 8'd10}[1:0];
    always @ (posedge clk)
        //20~27是传递数据
        //din从低位接收 因为接受到的是msb
        if((qpi_enable ? counter >= 14 : counter >= 20) && counter <= FINAL_COUNT)
            if(sck)
                data[byte_index] <= {data[byte_index][3:0], din}; // Optimize!

    // counter < 8: 发送命令 命令是按照1bit发送的 先发送MSB
    // counter 8~13: 发送地址 地址是按照4bit发送的 也是发送MSB
    assign dout     =   qpi_enable ?  
                        ((counter < 2) ? CMD_EBH[7 - 4 * counter -: 4] :
                        (counter == 2) ? saddr[23:20]        :
                        (counter == 3) ? saddr[19:16]        :
                        (counter == 4) ? saddr[15:12]        :
                        (counter == 5) ? saddr[11:8]         :
                        (counter == 6) ? saddr[7:4]          :
                        (counter == 7) ? saddr[3:0]          :
                        4'h0)
                        : 
                        ((counter < 8)  ?   {3'b0, CMD_EBH[7 - counter]}:
                        (counter == 8)  ?   saddr[23:20]        :
                        (counter == 9)  ?   saddr[19:16]        :
                        (counter == 10) ?   saddr[15:12]        :
                        (counter == 11) ?   saddr[11:8]         :
                        (counter == 12) ?   saddr[7:4]          :
                        (counter == 13) ?   saddr[3:0]          :
                        4'h0);

    // counter<14时 是向psram发送 cmd 和 addr
    assign douten   = qpi_enable ? (counter < 8) : (counter < 14);

    // counter == 28时 说明数据全接收到了
    assign done     = (counter == FINAL_COUNT+1);

    //line[7:0] - data[0]
    //line[15:8] - data[1]
    //line[23:16] - data[2]
    //line[31:24] - data[3]
    generate
        genvar i;
        for(i=0; i<4; i=i+1)
            assign line[i*8+7: i*8] = data[i];
    endgenerate

endmodule

// Using 38H Command
module PSRAM_WRITER (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            qpi_enable,
    input   wire [23:0]     addr,
    input   wire [31: 0]    line,
    input   wire [2:0]      size,
    input   wire            wr,
    output  wire            done,

    output  reg             sck,
    output  reg             ce_n,
    input   wire [3:0]      din,
    output  wire [3:0]      dout,
    output  wire            douten
);
    //localparam  DATA_START = 14;
    localparam  IDLE = 1'b0,
                WRITE = 1'b1;

    // 和READER一样 只不过size确实是根据 1 2 4有不同的数值 且没有延迟
    wire[7:0]        FINAL_COUNT = qpi_enable ? 7 + size * 2 : 13 + size*2;

    reg         state, nstate;
    reg [7:0]   counter;
    reg [23:0]  saddr;

    wire[7:0]   CMD_38H = 8'h38;

    always @*
        case (state)
            IDLE: if(wr) nstate = WRITE; else nstate = IDLE;
            WRITE: if(done) nstate = IDLE; else nstate = WRITE;
        endcase

    always @ (posedge clk or negedge rst_n)
        if(!rst_n) state <= IDLE;
        else state <= nstate;

    // Drive the Serial Clock (sck) @ clk/2
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            sck <= 1'b0;
        else if(~ce_n)
            sck <= ~ sck;
        else if(state == IDLE)
            sck <= 1'b0;

    // ce_n logic
    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            ce_n <= 1'b1;
        else if(state == WRITE)
            ce_n <= 1'b0;
        else
            ce_n <= 1'b1;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            counter <= 8'b0;
        else if(sck & ~done)
            counter <= counter + 1'b1;
        else if(state == IDLE)
            counter <= 8'b0;

    always @ (posedge clk or negedge rst_n)
        if(!rst_n)
            saddr <= 24'b0;
        else if((state == IDLE) && wr)
            saddr <= addr;

    // MSB 发送 command和addr
    // LSB 发送 数据line 且 每次先发送字节的高4bit
    assign dout     =   qpi_enable ? 
                        ((counter < 2)  ? CMD_38H[7 - 4 * counter -: 4] :
                        (counter == 2)  ?   saddr[23:20]        :
                        (counter == 3)  ?   saddr[19:16]        :
                        (counter == 4)  ?   saddr[15:12]        :
                        (counter == 5)  ?   saddr[11:8]         :
                        (counter == 6)  ?   saddr[7:4]          :
                        (counter == 7)  ?   saddr[3:0]          :
                        (counter == 8)  ?   line[7:4]           :
                        (counter == 9)  ?   line[3:0]           :
                        (counter == 10) ?   line[15:12]         :
                        (counter == 11) ?   line[11:8]          :
                        (counter == 12) ?   line[23:20]         :
                        (counter == 13) ?   line[19:16]         :
                        (counter == 14) ?   line[31:28]         :
                        line[27:24])
                        :
                        ((counter < 8)  ?   {3'b0, CMD_38H[7 - counter]}:
                        (counter == 8)  ?   saddr[23:20]        :
                        (counter == 9)  ?   saddr[19:16]        :
                        (counter == 10) ?   saddr[15:12]        :
                        (counter == 11) ?   saddr[11:8]         :
                        (counter == 12) ?   saddr[7:4]          :
                        (counter == 13) ?   saddr[3:0]          :
                        (counter == 14) ?   line[7:4]           :
                        (counter == 15) ?   line[3:0]           :
                        (counter == 16) ?   line[15:12]         :
                        (counter == 17) ?   line[11:8]          :
                        (counter == 18) ?   line[23:20]         :
                        (counter == 19) ?   line[19:16]         :
                        (counter == 20) ?   line[31:28]         :
                        line[27:24]);

    assign douten   = (~ce_n);

    assign done     = (counter == FINAL_COUNT + 1);

endmodule
