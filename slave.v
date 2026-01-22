module SPI_Slave #(
  parameter SPI_MODE = 0
)(
  input        i_Rst_L,    
  input        i_Clk,      

  input        i_SPI_Clk,
  input        i_SPI_CS_n,
  input        i_SPI_MOSI,
  output       o_SPI_MISO,

  input  [7:0] i_Slave_TX_Byte,
  output reg [7:0] o_Slave_RX_Byte,
  output reg       o_Slave_RX_DV
);

  // Initialize Output to 0 at start of simulation (Fixes initial XX)
  initial begin
    o_Slave_RX_Byte = 8'h00;
    o_Slave_RX_DV   = 1'b0;
  end

  // ------------------------------------------------------------
  // RX Section (Sampling MOSI)
  // ------------------------------------------------------------
  reg [7:0] r_RX_Shift;
  reg [2:0] r_RX_Bit;

  generate
    // Modes 0 & 3: Sample on RISING Edge
    if (SPI_MODE == 0 || SPI_MODE == 3) begin : RX_POSEDGE
      always @(posedge i_SPI_Clk or posedge i_SPI_CS_n) begin
        if (i_SPI_CS_n) begin
          // --- RESET STATE (CS High) ---
          r_RX_Bit      <= 3'd7;
          o_Slave_RX_DV <= 1'b0;
          r_RX_Shift    <= 8'h00; // <--- FIX: Clear internal shift reg only!
        end else begin
          // --- ACTIVE STATE (CS Low) ---
          r_RX_Shift[r_RX_Bit] <= i_SPI_MOSI;
          
          if (r_RX_Bit == 0) begin
            // Combine the previous 7 bits with the current bit
            o_Slave_RX_Byte <= {r_RX_Shift[7:1], i_SPI_MOSI};
            o_Slave_RX_DV   <= 1'b1;
            r_RX_Bit        <= 3'd7;
          end else begin
            r_RX_Bit      <= r_RX_Bit - 1'b1;
            o_Slave_RX_DV <= 1'b0;
          end
        end
      end
    end 
    // Modes 1 & 2: Sample on FALLING Edge
    else begin : RX_NEGEDGE
      always @(negedge i_SPI_Clk or posedge i_SPI_CS_n) begin
        if (i_SPI_CS_n) begin
          r_RX_Bit      <= 3'd7;
          o_Slave_RX_DV <= 1'b0;
          r_RX_Shift    <= 8'h00; // <--- FIX: Clear internal shift reg only!
        end else begin
          r_RX_Shift[r_RX_Bit] <= i_SPI_MOSI;
          
          if (r_RX_Bit == 0) begin
            o_Slave_RX_Byte <= {r_RX_Shift[7:1], i_SPI_MOSI};
            o_Slave_RX_DV   <= 1'b1;
            r_RX_Bit        <= 3'd7;
          end else begin
            r_RX_Bit      <= r_RX_Bit - 1'b1;
            o_Slave_RX_DV <= 1'b0;
          end
        end
      end
    end
  endgenerate

  // ------------------------------------------------------------
  // TX Section (Driving MISO)
  // ------------------------------------------------------------
  reg [7:0] r_TX_Shift;

  generate
    // Modes 0 & 1: Shift on FALLING Edge
    if (SPI_MODE == 0 || SPI_MODE == 1) begin : TX_NEGEDGE
      always @(negedge i_SPI_Clk or posedge i_SPI_CS_n) begin
        if (i_SPI_CS_n) begin
          r_TX_Shift <= i_Slave_TX_Byte;
        end else begin
          r_TX_Shift <= {r_TX_Shift[6:0], 1'b0};
        end
      end
    end 
    // Modes 2 & 3: Shift on RISING Edge
    else begin : TX_POSEDGE
      always @(posedge i_SPI_Clk or posedge i_SPI_CS_n) begin
        if (i_SPI_CS_n) begin
          r_TX_Shift <= i_Slave_TX_Byte;
        end else begin
          r_TX_Shift <= {r_TX_Shift[6:0], 1'b0};
        end
      end
    end
  endgenerate

  assign o_SPI_MISO = (i_SPI_CS_n) ? 1'bz : r_TX_Shift[7];

endmodule