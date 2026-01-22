`timescale 1ns/1ps

module SPI_Master_Slave_TB;

  reg r_Clk = 0;
  reg r_Rst_L = 0;

  reg  [7:0] r_Master_TX_Byte;
  reg        r_Master_TX_DV;
  wire       w_Master_Ready;

  wire w_SPI_Clk, w_SPI_MOSI, w_SPI_MISO, w_SPI_CS_n;
  wire [7:0] w_Master_RX_Byte;
  wire       w_Master_RX_DV;

  always #5 r_Clk = ~r_Clk;

  SPI_Master_With_Single_CS #(
    .SPI_MODE(3),
    .CLKS_PER_HALF_BIT(2)
  ) DUT_Master (
    .i_Clk      (r_Clk),
    .i_Rst_L    (r_Rst_L),
    .i_TX_Byte  (r_Master_TX_Byte),
    .i_TX_DV    (r_Master_TX_DV),
    .o_TX_Ready (w_Master_Ready),
    .o_RX_Byte  (w_Master_RX_Byte),
    .o_RX_DV    (w_Master_RX_DV),
    .o_SPI_Clk  (w_SPI_Clk),
    .o_SPI_MOSI (w_SPI_MOSI),
    .i_SPI_MISO (w_SPI_MISO),
    .o_SPI_CS_n (w_SPI_CS_n)
  );

  SPI_Slave #(.SPI_MODE(3)) DUT_Slave (
    .i_Rst_L        (r_Rst_L),
    .i_Clk          (r_Clk),
    .i_SPI_Clk      (w_SPI_Clk),
    .i_SPI_CS_n     (w_SPI_CS_n),
    .i_SPI_MOSI     (w_SPI_MOSI),
    .o_SPI_MISO     (w_SPI_MISO),
    .i_Slave_TX_Byte(8'hA5),
    .o_Slave_RX_Byte(),
    .o_Slave_RX_DV ()
  );

  initial begin
    r_Master_TX_Byte = 8'h00;
    r_Master_TX_DV   = 1'b0;

    // Reset
    r_Rst_L = 0;
    repeat (10) @(posedge r_Clk);
    r_Rst_L = 1;

    // Wait for ready
    wait (w_Master_Ready);

    // Send byte (1-cycle DV, as intended)
    @(posedge r_Clk);
    r_Master_TX_Byte <= 8'hC1;
    r_Master_TX_DV   <= 1'b1;

    @(posedge r_Clk);
    r_Master_TX_DV   <= 1'b0;

    // Wait for RX
    wait (w_Master_RX_DV);
    $display("[%0t] RX = %02X (expected A5)",
             $time, w_Master_RX_Byte);

    #100;
    $finish;
  end

endmodule
