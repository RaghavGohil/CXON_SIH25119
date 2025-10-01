//==================================================================
// V2X HSM Top Level Module - FIXED SHA-256 INTEGRATION
// Corrected signal mapping between protocol router and SHA core
//==================================================================

module v2x_hsm_top #(
    parameter SPI_DATA_WIDTH = 16,
    parameter SHA_ADDR_WIDTH = 8
)(
    // System Interface
    input  wire                    i_sys_clk,      // 100MHz system clock
    input  wire                    i_sys_rst_n,    // Active low reset
    
    // SPI Interface (ESP32 Master)
    input  wire                    i_spi_sclk,     // SPI clock from ESP32
    input  wire                    i_spi_mosi,     // Master out, slave in
    output wire                    o_spi_miso,     // Master in, slave out
    input  wire                    i_spi_cs_n,     // Chip select (active low)
    
    // Debug/Status LEDs
    output wire [7:0]              o_status_leds,
    output wire                    o_operation_led,
    output wire                    o_error_led
);

    // Internal signals
    wire [SPI_DATA_WIDTH-1:0]     spi_rx_data;
    wire                          spi_rx_valid;
    wire [SPI_DATA_WIDTH-1:0]     spi_tx_data;
    wire                          spi_tx_valid;
    wire                          spi_tx_ready;
    wire                          spi_tx_busy;
    wire                          spi_rx_error;
    wire                          spi_tx_error;

    // SHA-256 interface signals
    wire                          sha_cs;
    wire                          sha_we;
    wire [SHA_ADDR_WIDTH-1:0]     sha_address;
    wire [31:0]                   sha_write_data;
    wire [31:0]                   sha_read_data;
    wire                          sha_error;

    // Protocol router signals
    wire [7:0]                    status_reg;
    wire                          operation_complete;
    wire                          protocol_busy;

    // Fixed synchronization
    reg [3:0]                     spi_sync_reg;
    reg                           spi_tx_ready_sync;
    reg                           error_filter_reg;
    reg [7:0]                     error_debounce_counter;
    wire                          spi_active;
    
    assign spi_active = ~i_spi_cs_n;

    // CORRECTED: Simple TX ready logic - no complex synchronization needed
    assign spi_tx_ready = ~spi_tx_busy;

    // Simplified error filtering
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            error_filter_reg <= 1'b0;
            error_debounce_counter <= 8'b0;
        end else begin
            if (spi_rx_error || spi_tx_error || sha_error) begin
                if (error_debounce_counter < 8'd50) begin
                    error_debounce_counter <= error_debounce_counter + 1;
                end else begin
                    error_filter_reg <= 1'b1;
                end
            end else begin
                error_debounce_counter <= 8'b0;
                if (error_debounce_counter == 8'b0) begin
                    error_filter_reg <= 1'b0;
                end
            end
        end
    end

    // SPI Slave instance - CORRECTED connections
    spi_slave_v2x_top #(
        .DATA_WIDTH(SPI_DATA_WIDTH),
        .ADDR_WIDTH(8)
    ) u_spi_slave (
        .i_sys_clk      (i_sys_clk),
        .i_sys_rst_n    (i_sys_rst_n),
        .i_tx_data      (spi_tx_data),
        .o_rx_data      (spi_rx_data),
        .i_tx_valid     (spi_tx_valid),
        .o_rx_valid     (spi_rx_valid),
        .i_tx_ready     (spi_tx_ready),
        .o_tx_busy      (spi_tx_busy),
        .o_rx_error     (spi_rx_error),
        .o_tx_error     (spi_tx_error),
        .i_spi_sclk     (i_spi_sclk),
        .i_spi_mosi     (i_spi_mosi),
        .o_spi_miso     (o_spi_miso),
        .i_spi_cs_n     (i_spi_cs_n),
        .i_cpol         (1'b0),
        .i_cpha         (1'b0),  
        .i_lsb_first    (1'b0)
    );

    // Protocol Router instance
    v2x_protocol_router #(
        .DATA_WIDTH(SPI_DATA_WIDTH),
        .CMD_WIDTH(2),
        .SHA_ADDR_WIDTH(SHA_ADDR_WIDTH)
    ) u_protocol_router (
        .i_sys_clk              (i_sys_clk),
        .i_sys_rst_n            (i_sys_rst_n),
        .i_spi_rx_data          (spi_rx_data),
        .i_spi_rx_valid         (spi_rx_valid),
        .o_spi_tx_data          (spi_tx_data),
        .o_spi_tx_valid         (spi_tx_valid),
        .i_spi_tx_ready         (spi_tx_ready),
        .o_spi_busy             (protocol_busy),
        .o_sha_cs               (sha_cs),
        .o_sha_we               (sha_we),
        .o_sha_address          (sha_address),
        .o_sha_write_data       (sha_write_data),
        .i_sha_read_data        (sha_read_data),
        .i_sha_error            (sha_error),
        .o_status_reg           (status_reg),
        .o_operation_complete   (operation_complete)
    );

    // CRITICAL FIX: SHA-256 Core with CORRECT signal mapping
    sha256 u_sha256_core (
        .clk                    (i_sys_clk),
        .reset_n                (i_sys_rst_n),
        .cs                     (sha_cs),
        .we                     (sha_we),
        .address                (sha_address),
        .write_data             (sha_write_data),
        .read_data              (sha_read_data),
        .error                  (sha_error)
    );

    // Status and debug outputs
    assign o_status_leds = status_reg;
    assign o_operation_led = operation_complete;
    assign o_error_led = error_filter_reg;

endmodule
