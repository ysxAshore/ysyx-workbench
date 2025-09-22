module bitrev (
  input  wire       ss,     // chip select (active low)
  input  wire       sck,    // spi clock
  input  wire       mosi,   // master out slave in
  output reg        miso    // master in slave out
);
  //  assign miso = 1'b1;
  reg [3:0] bit_cnt; // 记录目前收到了几个bit
  reg [7:0] shift_in;
  reg [7:0] shift_out;

  // 上升沿采样 下降沿输出
  // posedge ss 异步复位
  // 这样每次传输结束后 都会恢复到默认状态
  always @(posedge sck or posedge ss) begin
	  if(ss) begin
		bit_cnt <= 'b0;
		shift_in <= 'b0;
		shift_out <= 'hff;
	  end else begin
		shift_in <= {shift_in[6:0], mosi}; //放最低位了
		shift_out <= {shift_out[6:0], 1'b0};
		bit_cnt <= bit_cnt + 1;
		if(bit_cnt == 'h7) begin
			shift_out <= {mosi, shift_in[0], shift_in[1], shift_in[2], shift_in[3], shift_in[4],
						  shift_in[5], shift_in[6]};
			bit_cnt <= 'h0;
		end
	  end
  end

  always @(negedge sck or posedge ss) begin
	if(ss) miso <= 'b1;
	else begin
		miso <= shift_out[7];
	end
  end

endmodule
