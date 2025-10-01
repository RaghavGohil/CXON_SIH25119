//==================================================================
// SPI Slave Controller for V2X HSM Architecture
// ESP32 (Master) <-> FPGA (Slave) Communication Interface
// Supports 16-bit data width for cryptographic operations
//==================================================================

module spi_slave_v2x_top #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 8
)(
    // System Interface
    input  wire                    i_sys_clk,      // System clock (100MHz)
    input  wire                    i_sys_rst_n,    // Active low reset
    
    // Processor Interface (HSM Command Interface)
    input  wire [DATA_WIDTH-1:0]   i_tx_data,      // Data to transmit to master
    output wire [DATA_WIDTH-1:0]   o_rx_data,      // Data received from master
    input  wire                    i_tx_valid,     // Transmit data valid
    output wire                    o_rx_valid,     // Receive data valid
    input  wire                    i_tx_ready,     // Ready to accept new TX data
    output wire                    o_tx_busy,      // Transmitter busy
    output wire                    o_rx_error,     // Receive buffer overrun
    output wire                    o_tx_error,     // Transmit buffer overrun
    
    // SPI Interface
    input  wire                    i_spi_sclk,     // SPI clock from master
    input  wire                    i_spi_mosi,     // Master out, slave in
    output wire                    o_spi_miso,     // Master in, slave out
    input  wire                    i_spi_cs_n,     // Chip select (active low)
    
    // Configuration Interface
    input  wire                    i_cpol,         // Clock polarity
    input  wire                    i_cpha,         // Clock phase
    input  wire                    i_lsb_first     // LSB first transmission
);

    // Internal signals
    wire spi_clk_edge;
    wire spi_sample_edge;
    wire cs_active;
    wire [DATA_WIDTH-1:0] tx_shift_data;
    wire [DATA_WIDTH-1:0] rx_shift_data;
    wire tx_load;
    wire rx_ready;
    wire spi_active;
    
    // Instantiate SPI slave core
    spi_slave_core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_core (
        .i_sys_clk      (i_sys_clk),
        .i_sys_rst_n    (i_sys_rst_n),
        .i_spi_sclk     (i_spi_sclk),
        .i_spi_mosi     (i_spi_mosi),
        .o_spi_miso     (o_spi_miso),
        .i_spi_cs_n     (i_spi_cs_n),
        .i_cpol         (i_cpol),
        .i_cpha         (i_cpha),
        .i_lsb_first    (i_lsb_first),
        .i_tx_data      (tx_shift_data),
        .o_rx_data      (rx_shift_data),
        .i_tx_load      (tx_load),
        .o_rx_valid     (rx_ready),
        .o_spi_active   (spi_active)
    );
    
    // Instantiate buffer management
    spi_buffer_manager #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_buffer_mgr (
        .i_sys_clk      (i_sys_clk),
        .i_sys_rst_n    (i_sys_rst_n),
        .i_tx_data      (i_tx_data),
        .o_rx_data      (o_rx_data),
        .i_tx_valid     (i_tx_valid),
        .o_rx_valid     (o_rx_valid),
        .i_tx_ready     (i_tx_ready),
        .o_tx_busy      (o_tx_busy),
        .o_rx_error     (o_rx_error),
        .o_tx_error     (o_tx_error),
        .o_tx_shift_data(tx_shift_data),
        .i_rx_shift_data(rx_shift_data),
        .o_tx_load      (tx_load),
        .i_rx_ready     (rx_ready),
        .i_spi_active   (spi_active),
        .i_spi_cs_n     (i_spi_cs_n)
    );

endmodule
