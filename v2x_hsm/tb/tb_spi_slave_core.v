`timescale 1ns/1ps

module tb_spi_slave_core;
  // Parameters
  parameter SYS_CLK_PERIOD = 10;  // 100 MHz
  parameter SPI_CLK_PERIOD = 100; // 10 MHz
  parameter DATA_WIDTH     = 16;

  // Inputs
  reg  sys_clk = 0;
  reg  sys_rst_n = 0;
  reg  spi_sclk = 0;
  reg  spi_mosi = 0;
  reg  spi_cs_n = 1;
  wire spi_miso;

  // SPI core outputs
  wire [DATA_WIDTH-1:0] rx_data;
  wire                 rx_valid;
  reg  [DATA_WIDTH-1:0] tx_data = 16'hA5A5;
  reg                  tx_load = 0;
  reg                  cpol = 0;
  reg                  cpha = 0;
  reg                  lsb_first = 0;

  // Instantiate SPI slave core
  spi_slave_core #(.DATA_WIDTH(DATA_WIDTH)) uut (
    .i_sys_clk    (sys_clk),
    .i_sys_rst_n  (sys_rst_n),
    .i_spi_sclk   (spi_sclk),
    .i_spi_mosi   (spi_mosi),
    .o_spi_miso   (spi_miso),
    .i_spi_cs_n   (spi_cs_n),
    .i_cpol       (cpol),
    .i_cpha       (cpha),
    .i_lsb_first  (lsb_first),
    .i_tx_data    (tx_data),
    .o_rx_data    (rx_data),
    .i_tx_load    (tx_load),
    .o_rx_valid   (rx_valid),
    .o_spi_active ()
  );

  // System clock
  always #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;

  // SPI clock (shift edges controlled by cpha=0, cpol=0 mode 0)
  always begin
    #(SPI_CLK_PERIOD/2) spi_sclk = ~spi_sclk;
  end

  initial begin
    $display("=== SPI Slave Core Testbench ===");
    // Apply reset
    sys_rst_n = 0;
    #(SYS_CLK_PERIOD*10);
    sys_rst_n = 1;
    $display("Release reset at time %t", $time);

    // Assert chip select
    spi_cs_n = 0;
    $display("Assert CS at time %t", $time);

    // Wait a cycle, then load TX data
    #(SYS_CLK_PERIOD);
    tx_load = 1;
    #(SYS_CLK_PERIOD);
    tx_load = 0;

    // Send 16 bits
    repeat (16) @(posedge spi_sclk) begin
      spi_mosi = $random; 
    end

    // Deassert chip select
    #(SPI_CLK_PERIOD);
    spi_cs_n = 1;
    $display("Deassert CS at time %t", $time);

    // Wait for core to flag rx_valid
    wait(rx_valid);
    $display("RX valid at time %t, data=0x%h", $time, rx_data);

    #1000;
    $finish;
  end
endmodule
