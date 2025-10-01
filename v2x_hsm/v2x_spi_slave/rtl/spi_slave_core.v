//==================================================================
// SPI Slave Core - Handles SPI protocol timing and data shifting
//==================================================================

module spi_slave_core #(
    parameter DATA_WIDTH = 16
)(
    input  wire                    i_sys_clk,
    input  wire                    i_sys_rst_n,
    input  wire                    i_spi_sclk,
    input  wire                    i_spi_mosi,
    output reg                     o_spi_miso,
    input  wire                    i_spi_cs_n,
    input  wire                    i_cpol,
    input  wire                    i_cpha,
    input  wire                    i_lsb_first,
    input  wire [DATA_WIDTH-1:0]   i_tx_data,
    output wire [DATA_WIDTH-1:0]   o_rx_data,
    input  wire                    i_tx_load,
    output reg                     o_rx_valid,
    output wire                    o_spi_active
);

    // SPI clock edge detection
    reg [2:0] sclk_sync;
    reg [2:0] cs_sync;
    
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            sclk_sync <= 3'b000;
            cs_sync <= 3'b111;
        end else begin
            sclk_sync <= {sclk_sync[1:0], i_spi_sclk};
            cs_sync <= {cs_sync[1:0], i_spi_cs_n};
        end
    end
    
    wire sclk_posedge = (sclk_sync[2:1] == 2'b01);
    wire sclk_negedge = (sclk_sync[2:1] == 2'b10);
    wire cs_active = ~cs_sync[1];
    wire cs_falling = (cs_sync[2:1] == 2'b10);
    
    assign o_spi_active = cs_active;
    
    // Determine sample and shift edges based on CPOL/CPHA
    wire sample_edge = (i_cpol == 1'b0) ? 
                       (i_cpha == 1'b0 ? sclk_posedge : sclk_negedge) :
                       (i_cpha == 1'b0 ? sclk_negedge : sclk_posedge);
                       
    wire shift_edge = (i_cpol == 1'b0) ? 
                      (i_cpha == 1'b0 ? sclk_negedge : sclk_posedge) :
                      (i_cpha == 1'b0 ? sclk_posedge : sclk_negedge);
    
    // Bit counter
    reg [$clog2(DATA_WIDTH):0] bit_count;
    
    // Shift registers
    reg [DATA_WIDTH-1:0] tx_shift_reg;
    reg [DATA_WIDTH-1:0] rx_shift_reg;
    
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            bit_count <= 0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            o_rx_valid <= 1'b0;
            o_spi_miso <= 1'b0;
        end else begin
            if (cs_falling || !cs_active) begin
                // Transaction start or CS inactive
                bit_count <= 0;
                o_rx_valid <= 1'b0;
                if (i_tx_load) begin
                    tx_shift_reg <= i_tx_data;
                end
            end else if (cs_active) begin
                // Sample on appropriate edge
                if (sample_edge) begin
                    if (i_lsb_first) begin
                        rx_shift_reg <= {i_spi_mosi, rx_shift_reg[DATA_WIDTH-1:1]};
                    end else begin
                        rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], i_spi_mosi};
                    end
                    bit_count <= bit_count + 1;
                    
                    // Check for complete word
                    if (bit_count == DATA_WIDTH - 1) begin
                        o_rx_valid <= 1'b1;
                        bit_count <= 0;
                    end
                end
                
                // Shift output on appropriate edge
                if (shift_edge || (i_cpha == 1'b0 && bit_count == 0)) begin
                    if (i_lsb_first) begin
                        o_spi_miso <= tx_shift_reg;
                        tx_shift_reg <= {1'b0, tx_shift_reg[DATA_WIDTH-1:1]};
                    end else begin
                        o_spi_miso <= tx_shift_reg[DATA_WIDTH-1];
                        tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
                    end
                end
            end
        end
    end
    
    assign o_rx_data = rx_shift_reg;

endmodule
