///////////////////////////////////////////////////////////////////////////////
// Description:       Corrected test bench for SPI Master with CS
///////////////////////////////////////////////////////////////////////////////

module SPI_Master_With_Single_CS_TB ();
  
  parameter SPI_MODE = 3;           // CPOL = 1, CPHA = 1
  parameter CLKS_PER_HALF_BIT = 4;  // 6.25 MHz
  parameter MAIN_CLK_DELAY = 2;     // 25 MHz
  parameter MAX_BYTES_PER_CS = 2;   // 2 bytes per chip select
  parameter CS_INACTIVE_CLKS = 10;  // Adds delay between bytes

  // Signals driven by the Testbench -> Must be reg
  reg r_Rst_L = 1'b0;  
  reg r_Clk   = 1'b0;
  reg [7:0] r_Master_TX_Byte = 0;
  reg r_Master_TX_DV = 1'b0;
  reg [1:0] r_Master_TX_Count = 2'b10; // Requesting 2 bytes per CS

  // Signals driven by the Module Outputs -> Must be wire
  wire w_SPI_Clk;
  wire w_SPI_CS_n;
  wire w_SPI_MOSI;
  wire w_SPI_MISO; // Separate wire for loopback
  wire w_Master_TX_Ready;
  wire w_Master_RX_DV;
  wire [7:0] w_Master_RX_Byte;
  wire [1:0] w_Master_RX_Count;

  // External Loopback Connection
  assign w_SPI_MISO = w_SPI_MOSI;

  // Clock Generator
  always #(MAIN_CLK_DELAY) r_Clk = ~r_Clk;

  // Instantiate UUT
  SPI_Master_With_Single_CS
  #( .SPI_MODE(SPI_MODE),
     .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
     .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
     .CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
   ) UUT
  (
    // Control/Data Signals
    .i_Rst_L(r_Rst_L),     
    .i_Clk(r_Clk),         
    
    // TX (MOSI) Signals
    .i_TX_Count(r_Master_TX_Count),   
    .i_TX_Byte(r_Master_TX_Byte),     
    .i_TX_DV(r_Master_TX_DV),         
    .o_TX_Ready(w_Master_TX_Ready),   
    
    // RX (MISO) Signals
    .o_RX_Count(w_Master_RX_Count), 
    .o_RX_DV(w_Master_RX_DV),       
    .o_RX_Byte(w_Master_RX_Byte),   

    // SPI Interface
    .o_SPI_Clk(w_SPI_Clk),
    .i_SPI_MISO(w_SPI_MISO),
    .o_SPI_MOSI(w_SPI_MOSI),
    .o_SPI_CS_n(w_SPI_CS_n)
   );

  // Sends a single byte from master.
  task SendSingleByte(input [7:0] data);
    begin
      @(posedge r_Clk);
      r_Master_TX_Byte <= data;
      r_Master_TX_DV   <= 1'b1;
      @(posedge r_Clk);
      r_Master_TX_DV   <= 1'b0;
      // Wait for the TX Ready flag to signal transfer completion
      @(posedge w_Master_TX_Ready);
    end
  endtask 

  initial
    begin
      $dumpfile("dump.vcd"); 
      $dumpvars(0, SPI_Master_With_Single_CS_TB);
      
      // Reset Sequence
      r_Rst_L = 1'b0;
      repeat(10) @(posedge r_Clk);
      r_Rst_L = 1'b1;
      //repeat(10) @(posedge r_Clk);
      // WAIT for the hardware to say it is ready before sending C1
        wait(w_Master_TX_Ready == 1'b1); 
        repeat(5) @(posedge r_Clk); // Small safety buffer
      // Test sending 2 bytes within one Chip Select (CS) cycle
      // The Hardware should keep CS low between these two calls
      SendSingleByte(8'hC1);
      $display("Sent out 0xC1, Received 0x%X", w_Master_RX_Byte); 
      
      SendSingleByte(8'hC2);
      $display("Sent out 0xC2, Received 0x%X", w_Master_RX_Byte); 

      repeat(100) @(posedge r_Clk);
      $finish();      
    end

endmodule