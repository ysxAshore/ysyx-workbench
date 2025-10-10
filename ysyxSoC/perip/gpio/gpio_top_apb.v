module gpio_top_apb(
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

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

  reg [15:0] led_data;
  reg [15:0] switch_data;
  reg [31:0] seg_data;
  reg ready;

  assign in_pready = ready && in_penable;
  assign in_pslverr = 1'b0;
  assign in_prdata = {16'b0,switch_data};
  assign gpio_out = led_data;
  assign gpio_seg_0 = seg7_fn(seg_data[3:0]);
  assign gpio_seg_1 = seg7_fn(seg_data[7:4]);
  assign gpio_seg_2 = seg7_fn(seg_data[11:8]);
  assign gpio_seg_3 = seg7_fn(seg_data[15:12]);
  assign gpio_seg_4 = seg7_fn(seg_data[19:16]);
  assign gpio_seg_5 = seg7_fn(seg_data[23:20]);
  assign gpio_seg_6 = seg7_fn(seg_data[27:24]);
  assign gpio_seg_7 = seg7_fn(seg_data[31:28]);

  always @(posedge clock or posedge reset) begin
	  if(reset) begin
		led_data <= 16'b0;
		switch_data <= 16'b0;
		seg_data <= 32'b0;
		ready <= 1'b0;
	  end else begin
		  if(in_psel && ~in_pwrite) begin
			  if(in_paddr[3:0] == 4'h4) begin //读拨码
				 ready <= 1'b1;
				 switch_data <= gpio_in;
			  end else begin //不支持写操作
				 $fwrite(32'h80000002, "Assertion failed: Unsupported address `%xh` read, only support `0x4` address read\n", in_paddr[3:0]);
				 $fatal;
			  end
		  end else if(in_psel && in_pwrite) begin
			  if(in_paddr[3:0] == 4'h0) begin //写led
				 case(in_pstrb)
					4'h1       : led_data <= {led_data[15:8],in_pwdata[7:0]};
					4'h2       : led_data <= {in_pwdata[15:8],led_data[7:0]};
					4'h3, 4'hf : led_data <= in_pwdata[15:0];
					default	   : led_data <= led_data;
				 endcase
				 ready <= 1'b1;
			  end else if(in_paddr[3:0] == 4'h8) begin //写seg
				 case(in_pstrb)
					4'h1       : seg_data <= {seg_data[31:8],in_pwdata[7:0]};
					4'h2       : seg_data <= {seg_data[31:16],in_pwdata[15:8],seg_data[7:0]};
					4'h4       : seg_data <= {seg_data[31:24],in_pwdata[23:16],seg_data[15:0]};
					4'h8       : seg_data <= {in_pwdata[31:24],seg_data[23:0]};
					4'h3       : seg_data <= {seg_data[31:16],in_pwdata[15:0]};
					4'hc       : seg_data <= {in_pwdata[31:16],seg_data[15:0]};
					4'hf       : seg_data <= in_pwdata;
					default	   : seg_data <= seg_data;
				 endcase
				 ready <= 1'b1;
			  end else begin //led和seg都只支持读操作
				 $fwrite(32'h80000002, "Assertion failed: Unsupported address `%xh` write, only support `0x0` , `0x8` address write\n", in_paddr[3:0]);
				 $fatal;
			  end
		  end
	  end
  end

  // 8 位输出：{a,b,c,d,e,f,g,dp}
  // 共阳极
  function [7:0] seg7_fn;
    input [3:0] bcd;      // 输入数字 0-15
    reg [6:0] seg7;
    begin
      case (bcd)
        4'h0: seg7 = 7'b000_0001;
        4'h1: seg7 = 7'b100_1111;
        4'h2: seg7 = 7'b001_0010;
        4'h3: seg7 = 7'b000_0110;
        4'h4: seg7 = 7'b100_1100;
        4'h5: seg7 = 7'b010_0100;
        4'h6: seg7 = 7'b010_0000;
        4'h7: seg7 = 7'b000_1111;
        4'h8: seg7 = 7'b000_0000;
        4'h9: seg7 = 7'b000_0100;
        default: seg7 = 7'b000_0000; // 熄灭
      endcase
      seg7_fn = {seg7, 1'b0}; // 高位 7:1 是段码，bit0 是小数点
    end
  endfunction
endmodule
