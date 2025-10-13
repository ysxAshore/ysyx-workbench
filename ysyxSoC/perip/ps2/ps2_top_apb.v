module ps2_top_apb(
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

  input         ps2_clk,
  input         ps2_data
);
  localparam FIFO_W = 4;
  reg [7:0] fifo[0:(1<<FIFO_W)-1];
  reg [3:0] count;
  reg [2:0] ps2_clk_sync;
  reg [FIFO_W-1:0] w_ptr;
  reg [FIFO_W-1:0] r_ptr;
  reg [9:0] buffer;

  reg data_valid;
  reg [7:0] rdata;

  wire apb_read = in_psel && in_paddr == 32'h1001_1000 && ~in_pwrite & ~in_penable;

  always @(posedge clock) begin
    ps2_clk_sync <= {ps2_clk_sync[1:0],ps2_clk};
  end

  wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];

  always @(posedge clock) begin
    if(reset) begin 
      count <= 0;
      w_ptr <= 0;
      r_ptr <= 0;
      rdata <= 'b0;
      data_valid <= 'b0;
    end else begin
      if(sampling) begin
        if(count == 4'd10) begin
          if((buffer[0] == 0) && //start bit
             (ps2_data)    && //stop bit
             (^buffer[9:1])) begin // odd parity
            fifo[w_ptr] <= buffer[8:1];
            w_ptr <= w_ptr + 'b1;  
          end
          count <= 0;
        end else begin
          buffer[count] <= ps2_data;
          count <= count + 'b1;
        end
      end

      if(apb_read) begin
        data_valid <= 'b1;
        rdata <= (w_ptr == r_ptr) ? 'b0 : fifo[r_ptr];
        if(w_ptr != r_ptr) begin
          r_ptr <= r_ptr + 'b1;
        end
      end else begin
        rdata <= 'b0;
        data_valid <= 'b0;
      end
    end
  end


  // APB固定应答
  assign in_pslverr = 'b0;
  assign in_pready = in_penable && data_valid; 
  assign in_prdata = {24'b0,rdata};

endmodule