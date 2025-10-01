//==================================================================
// SPI Buffer Manager - Handles data buffering and flow control
//==================================================================

module spi_buffer_manager #(
    parameter DATA_WIDTH = 16
)(
    input  wire                    i_sys_clk,
    input  wire                    i_sys_rst_n,
    input  wire [DATA_WIDTH-1:0]   i_tx_data,
    output reg  [DATA_WIDTH-1:0]   o_rx_data,
    input  wire                    i_tx_valid,
    output reg                     o_rx_valid,
    input  wire                    i_tx_ready,
    output reg                     o_tx_busy,
    output reg                     o_rx_error,
    output reg                     o_tx_error,
    output reg  [DATA_WIDTH-1:0]   o_tx_shift_data,
    input  wire [DATA_WIDTH-1:0]   i_rx_shift_data,
    output reg                     o_tx_load,
    input  wire                    i_rx_ready,
    input  wire                    i_spi_active,
    input  wire                    i_spi_cs_n
);

    // TX Buffer
    reg [DATA_WIDTH-1:0] tx_buffer;
    reg tx_buffer_valid;
    reg tx_loaded;
    
    // RX Buffer
    reg [DATA_WIDTH-1:0] rx_buffer;
    reg rx_buffer_valid;
    
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            tx_buffer <= 0;
            tx_buffer_valid <= 1'b0;
            tx_loaded <= 1'b0;
            o_tx_busy <= 1'b0;
            o_tx_error <= 1'b0;
            o_tx_load <= 1'b0;
            o_tx_shift_data <= 0;
        end else begin
            o_tx_load <= 1'b0;
            
            // Handle TX data loading
            if (i_tx_valid && i_tx_ready) begin
                if (tx_buffer_valid && !tx_loaded) begin
                    o_tx_error <= 1'b1; // Buffer overrun
                end else begin
                    tx_buffer <= i_tx_data;
                    tx_buffer_valid <= 1'b1;
                    tx_loaded <= 1'b0;
                    o_tx_busy <= 1'b1;
                end
            end
            
            // Load data to shift register when SPI becomes active
            if (!i_spi_cs_n && tx_buffer_valid && !tx_loaded) begin
                o_tx_shift_data <= tx_buffer;
                o_tx_load <= 1'b1;
                tx_loaded <= 1'b1;
            end
            
            // Clear busy when transaction completes
            if (i_spi_cs_n && tx_loaded) begin
                tx_buffer_valid <= 1'b0;
                tx_loaded <= 1'b0;
                o_tx_busy <= 1'b0;
            end
            
            // Clear error on next valid transaction
            if (i_tx_valid && !o_tx_error) begin
                o_tx_error <= 1'b0;
            end
        end
    end
    
    // RX Buffer management
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            rx_buffer <= 0;
            rx_buffer_valid <= 1'b0;
            o_rx_data <= 0;
            o_rx_valid <= 1'b0;
            o_rx_error <= 1'b0;
        end else begin
            // Capture received data
            if (i_rx_ready) begin
                if (rx_buffer_valid) begin
                    o_rx_error <= 1'b1; // Buffer overrun
                end else begin
                    rx_buffer <= i_rx_shift_data;
                    rx_buffer_valid <= 1'b1;
                    o_rx_data <= i_rx_shift_data;
                    o_rx_valid <= 1'b1;
                end
            end else begin
                o_rx_valid <= 1'b0;
            end
            
            // Clear buffer when data is read
            if (o_rx_valid) begin
                rx_buffer_valid <= 1'b0;
            end
            
            // Clear error on successful read
            if (o_rx_valid && !rx_buffer_valid) begin
                o_rx_error <= 1'b0;
            end
        end
    end

endmodule
