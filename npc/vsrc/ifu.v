module ifu #(DATA_WIDTH = 32)(
  input clk,
  input rst,
  output reg [DATA_WIDTH - 1 : 0] pc
);
  wire [DATA_WIDTH - 1 : 0] snpc;
  assign snpc = pc + 'h4;

  always @(posedge clk)begin
    if(rst)
      pc <= 'h8000_0000;
    else 
      pc <= snpc;
  end

endmodule