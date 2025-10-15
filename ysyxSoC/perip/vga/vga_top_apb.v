module vga_top_apb(
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

  output [7:0]  vga_r,
  output [7:0]  vga_g,
  output [7:0]  vga_b,
  output        vga_hsync,
  output        vga_vsync,
  output        vga_valid
);
  wire vga_clk;
  clkgen #(25000000) u_clkgen (
    .clk_in(clock),
    .rst(reset),
    .clk_out(vga_clk)
  );
  reg [23:0] vga_mem [524287:0];
  wire [9:0] h_addr;
  wire [9:0] v_addr;
  wire [23:0] vga_data = vga_mem[{h_addr, v_addr[8:0]}];

 // initial begin
 //   $readmemh("/home/sxyang/Projects/ysyx-workbench/nvboard/example/resource/picture.hex", vga_mem);
 // end

  vga_ctrl u_vga_ctrl (
    .pclk   (clock),
    .reset  (reset),
    .vga_data(vga_data),
    .h_addr (h_addr),
    .v_addr (v_addr),
    .hsync  (vga_hsync),
    .vsync  (vga_vsync),
    .valid  (vga_valid),
    .vga_r  (vga_r),
    .vga_g  (vga_g),
    .vga_b  (vga_b)
  );

  reg pready;
  reg [31:0] prdata;

  assign in_pready = in_penable & pready;
  assign in_prdata = prdata;
  assign in_pslverr = 0;

 always @(posedge clock) begin
   if(reset) begin 
     pready <= 0;
   end else begin
     if(in_psel) begin
       pready <= 1;
       if(in_pwrite) begin
           vga_mem[in_paddr[20:2]] <= in_pwdata[23:0]; //默认4B写
       end else begin
         prdata <= {8'b0,vga_mem[in_paddr[20:2]]}; //read时4B读
       end
     end else begin
       pready <= 0;
     end
   end
 end
endmodule

module clkgen #(parameter CLK_GEN = 25000000)(
  input  clk_in,
  input  rst,
  output reg clk_out
);
  parameter CNT_MAX = 50000000 / CLK_GEN / 2;
  reg [31:0] cnt;
  always @(posedge clk_in or posedge rst) begin
    if (rst) begin
      cnt <= 32'b0;
      clk_out <= 1'b0;
    end else begin
      if (cnt == CNT_MAX - 1) begin
        cnt <= 32'b0;
        clk_out <= ~clk_out;
      end else begin
        cnt <= cnt + 1;
      end
    end
  end

endmodule
