# Verilog SPI Master-Slave Interface

A robust, synthesizable implementation of the Serial Peripheral Interface (SPI) protocol in Verilog. This project features a highly reliable Slave module designed to handle tight timing constraints and race conditions, along with a configurable Master module.

## Key Features

* **Robust Slave Design:** Implements a "Race-Proof" architecture. The slave correctly handles scenarios where `CS_n` (Chip Select) goes inactive simultaneously with the final `SPI_Clk` edge, ensuring the LSB is captured safely without data loss.
* **Configurable Modes:** Supports standard SPI Modes 0 and 3 (CPOL=0/1, CPHA=0/1) via parameters.
* **Burst-Ready Architecture:** The Slave's bit-counter logic is designed to support back-to-back byte transfers (Burst Mode) without requiring a `CS_n` toggle between bytes.
* **Parameterized Timing:** The Master module supports configurable clock division (`CLKS_PER_HALF_BIT`) to interface with various system clock speeds.

## Project Structure

* `SPI_Master.v`: The SPI Master core. Generates `SPI_Clk`, handles `CS_n` assertion, and drives MOSI. Includes logic for flexible transaction lengths.
* `SPI_Slave.v`: The SPI Slave core. Features an asynchronous reset on the *start* of the packet (`negedge CS_n`) rather than the end, eliminating common race conditions found in standard implementations.
* `SPI_Testbench.v`: A self-checking testbench that connects the Master and Slave, verifying data integrity across transfers.

## Theory of Operation

### The "Race Condition" Fix
Standard SPI Slave implementations often reset their bit counters asynchronously on `posedge CS_n`. However, if the Master de-asserts `CS_n` instantly after the last clock edge (Zero Hold Time), the reset logic can override the final data capture.

**My Solution:**
This design triggers the internal counter reset on the **Start of Frame** (`negedge CS_n`). This ensures that the "End of Frame" event is invisible to the reset logic, allowing the final bit to be captured reliably regardless of the Master's hold time.

##  Simulation & Testing

This project has been verified using [ModelSim / Vivado / Icarus Verilog].

**Test Case:**
1.  Master initiates a transfer of byte `0xC1` (1100 0001).
2.  Slave captures data on the rising edge of `SPI_Clk`.
3.  **Result:** Slave successfully outputs `0xC1` on `o_RX_Byte` and asserts `o_RX_DV` valid signal, confirming the fix for the LSB capture issue.

##  Future Roadmap

* Integration with RISC-V SoC (APB/AHB Wrapper).
* Full verification of multi-byte Burst Mode transfers.
* Synthesis and timing analysis on FPGA target.
