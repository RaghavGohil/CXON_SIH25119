`timescale 1ns / 1ps

//==================================================================
// Protocol Router Testbench with SHA Stub and event-driven finish
//==================================================================

module tb_protocol_router();

    // Parameters
    parameter CLK_PERIOD = 10;
    parameter DATA_WIDTH = 16;
    
    // Test signals
    reg                     sys_clk;
    reg                     sys_rst_n;
    reg  [DATA_WIDTH-1:0]   spi_rx_data;
    reg                     spi_rx_valid;
    wire [DATA_WIDTH-1:0]   spi_tx_data;
    wire                    spi_tx_valid;
    reg                     spi_tx_ready;
    wire                    spi_busy;
    
    // SHA interface (stubbed)
    wire                    sha_cs;
    wire                    sha_we;
    wire [7:0]              sha_address;
    wire [31:0]             sha_write_data;
    reg  [31:0]             sha_read_data;
    reg                     sha_error;
    
    // Status outputs
    wire [7:0]              status_reg;
    wire                    operation_complete;
    
    // Internal variable
    integer                 dw;
    
    // Instantiate protocol router
    v2x_protocol_router #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .i_sys_clk              (sys_clk),
        .i_sys_rst_n            (sys_rst_n),
        .i_spi_rx_data          (spi_rx_data),
        .i_spi_rx_valid         (spi_rx_valid),
        .o_spi_tx_data          (spi_tx_data),
        .o_spi_tx_valid         (spi_tx_valid),
        .i_spi_tx_ready         (spi_tx_ready),
        .o_spi_busy             (spi_busy),
        .o_sha_cs               (sha_cs),
        .o_sha_we               (sha_we),
        .o_sha_address          (sha_address),
        .o_sha_write_data       (sha_write_data),
        .i_sha_read_data        (sha_read_data),
        .i_sha_error            (sha_error),
        .o_status_reg           (status_reg),
        .o_operation_complete   (operation_complete)
    );
    
    // Clock generation
    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD/2) sys_clk = ~sys_clk;
    end
    
    initial begin
        $display("=== Protocol Router Testbench with SHA Stub ===");
        
        // Initialize
        sys_rst_n     = 1'b0;
        spi_rx_data   = 16'h0000;
        spi_rx_valid  = 1'b0;
        spi_tx_ready  = 1'b1;
        sha_read_data = 32'h00000000;
        sha_error     = 1'b0;
        
        // Reset pulse
        #(CLK_PERIOD * 10);
        sys_rst_n = 1'b1;
        #(CLK_PERIOD * 5);
        $display("Reset complete. status_reg = %h", status_reg);
        
        // Send SHA command (OP=00, LEN=2)
        $display("Sending SHA-256 command...");
        spi_rx_data  = 16'h0200;
        spi_rx_valid = 1'b1;
        #(CLK_PERIOD);
        spi_rx_valid = 1'b0;
        #(CLK_PERIOD * 5);
        $display("status_reg after cmd = %h", status_reg);
        
        // Send data word ("ab")
        $display("Sending data word...");
        spi_rx_data  = 16'h6162;
        spi_rx_valid = 1'b1;
        #(CLK_PERIOD);
        spi_rx_valid = 1'b0;
        #(CLK_PERIOD * 10);
        $display("status_reg after data = %h", status_reg);
        $display("SHA CS=%b WE=%b Addr=%h", sha_cs, sha_we, sha_address);
        
        // Stub SHA status and digest
        wait (sha_cs && sha_address == 8'h09);
        sha_read_data = 32'h00000003;  // READY=1, VALID=1
        #(CLK_PERIOD);
        
        for (dw = 0; dw < 8; dw = dw + 1) begin
            wait (sha_cs && sha_address == (8'h20 + dw));
            sha_read_data = 32'hDEAD0000 | dw;
            #(CLK_PERIOD);
        end
        
        // Wait for operation_complete
        wait (operation_complete);
        $display("operation_complete asserted at time %t", $time);
        $display("Final status_reg = %h", status_reg);
        $finish;
    end
    
    // Monitor status changes
    always @(status_reg) begin
        $display("Status changed to %h at time %t", status_reg, $time);
    end
    
    // Extended timeout
    initial begin
        #500_000;
        $display("ERROR: Timeout waiting for operation_complete");
        $finish;
    end

endmodule
