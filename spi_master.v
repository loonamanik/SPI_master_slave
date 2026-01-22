module SPI_Master #(
  parameter SPI_MODE = 0,
  parameter CLKS_PER_HALF_BIT = 2
)(
  input  wire        i_Clk,
  input  wire        i_Rst_L,

  input  wire [7:0]  i_TX_Byte,
  input  wire        i_TX_DV,
  output reg         o_TX_Ready,

  output reg  [7:0]  o_RX_Byte,
  output reg         o_RX_DV,

  output reg         o_SPI_Clk,
  output reg         o_SPI_MOSI,
  input  wire        i_SPI_MISO,

  input  wire        i_frame_start,
  input  wire        i_frame_end
);

  // ------------------------------------------------------------
  // SPI mode decode
  // ------------------------------------------------------------
  wire w_CPOL = (SPI_MODE == 2) || (SPI_MODE == 3);
  wire w_CPHA = (SPI_MODE == 1) || (SPI_MODE == 3);

  // ------------------------------------------------------------
  // Clock generation
  // ------------------------------------------------------------
  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_ClkCnt;
  reg [4:0]  r_EdgeCnt;
  reg        r_ClkInt;
  reg        r_Leading_Edge, r_Trailing_Edge;
  reg        r_Active;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      r_ClkCnt <= 0;
      r_EdgeCnt <= 0;
      r_ClkInt <= w_CPOL;
      r_Active <= 0;
      o_TX_Ready <= 1;
      r_Leading_Edge <= 0;
      r_Trailing_Edge <= 0;
    end else begin
      r_Leading_Edge <= 0;
      r_Trailing_Edge <= 0;

      if (i_TX_DV && o_TX_Ready) begin
        r_Active <= 1;
        r_EdgeCnt <= 16;
        r_ClkCnt <= 0;
        o_TX_Ready <= 0;
      end else if (r_Active) begin
        if (r_ClkCnt == CLKS_PER_HALF_BIT-1) begin
          r_ClkCnt <= r_ClkCnt + 1;
          r_Leading_Edge <= 1;
          r_ClkInt <= ~r_ClkInt;
          r_EdgeCnt <= r_EdgeCnt - 1;
        end else if (r_ClkCnt == CLKS_PER_HALF_BIT*2-1) begin
          r_ClkCnt <= 0;
          r_Trailing_Edge <= 1;
          r_ClkInt <= ~r_ClkInt;
          r_EdgeCnt <= r_EdgeCnt - 1;
        end else begin
          r_ClkCnt <= r_ClkCnt + 1;
        end

        if (r_EdgeCnt == 0) begin
          r_Active <= 0;
          o_TX_Ready <= 1;
        end
      end
    end
  end

  always @(posedge i_Clk or negedge i_Rst_L)
    if (!i_Rst_L) o_SPI_Clk <= w_CPOL;
    else          o_SPI_Clk <= r_ClkInt;

  // ------------------------------------------------------------
  // MOSI (TX)
  // ------------------------------------------------------------
  reg [7:0] r_TX_Shift;
  reg [2:0] r_TX_Bit;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      o_SPI_MOSI <= 0;
      r_TX_Bit <= 7;
    end else begin
      if (i_frame_start) begin
        r_TX_Shift <= i_TX_Byte;
        r_TX_Bit <= 7;
      end else if (r_Active &&
        ((r_Leading_Edge & w_CPHA) || (r_Trailing_Edge & ~w_CPHA))) begin
        o_SPI_MOSI <= r_TX_Shift[r_TX_Bit];
        r_TX_Bit <= r_TX_Bit - 1;
      end
    end
  end

  // ------------------------------------------------------------
  // MISO (RX) — FRAME SAFE
  // ------------------------------------------------------------
  reg [2:0] r_RX_Bit;
  reg       r_Sample_Enable;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (!i_Rst_L) begin
      o_RX_Byte <= 0;
      o_RX_DV <= 0;
      r_RX_Bit <= 7;
      r_Sample_Enable <= 0;
    end else begin
      o_RX_DV <= 0;

      if (i_frame_start) begin
        r_RX_Bit <= 7;
        r_Sample_Enable <= 0;
      end else if (r_Leading_Edge) begin
        r_Sample_Enable <= 1;
      end else if (r_Active && r_Sample_Enable &&
        ((r_Leading_Edge & ~w_CPHA) || (r_Trailing_Edge & w_CPHA))) begin
        o_RX_Byte[r_RX_Bit] <= i_SPI_MISO;
        r_RX_Bit <= r_RX_Bit - 1;
        if (r_RX_Bit == 0)
          o_RX_DV <= 1;
      end
    end
  end

endmodule
