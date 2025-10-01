//==================================================================
// V2X Protocol Router
// Operation Codes:
// 00: SHA-256 Hash
// 01: AES-GCM
// 02: TRNG
// 03: Key Vault
//==================================================================

module v2x_protocol_router #(
    parameter DATA_WIDTH = 16,
    parameter CMD_WIDTH = 2,
    parameter SHA_ADDR_WIDTH = 8
)(
    // System Interface
    input  wire                    i_sys_clk,
    input  wire                    i_sys_rst_n,
    
    // SPI Interface
    input  wire [DATA_WIDTH-1:0]   i_spi_rx_data,
    input  wire                    i_spi_rx_valid,
    output reg  [DATA_WIDTH-1:0]   o_spi_tx_data,
    output reg                     o_spi_tx_valid,
    input  wire                    i_spi_tx_ready,
    output wire                    o_spi_busy,
    
    // SHA-256 Interface
    output reg                     o_sha_cs,
    output reg                     o_sha_we,
    output reg  [SHA_ADDR_WIDTH-1:0] o_sha_address,
    output reg  [31:0]             o_sha_write_data,
    input  wire [31:0]             i_sha_read_data,
    input  wire                    i_sha_error,
    
    // Status and Control
    output reg  [7:0]              o_status_reg,
    output reg                     o_operation_complete
);

    // State machine states
    localparam IDLE              = 4'b0000;
    localparam DECODE_CMD        = 4'b0001;
    localparam RECEIVE_DATA      = 4'b0010;
    localparam SHA_INIT          = 4'b0011;
    localparam SHA_LOAD_BLOCK    = 4'b0100;
    localparam SHA_PROCESS       = 4'b0101;
    localparam SHA_WAIT_READY    = 4'b0110;
    localparam SHA_READ_DIGEST   = 4'b0111;
    localparam SEND_RESPONSE     = 4'b1000;
    localparam ERROR_STATE       = 4'b1001;

    // Operation codes
    localparam OP_SHA256         = 2'b00;
    localparam OP_AES_GCM        = 2'b01;  // Future
    localparam OP_TRNG           = 2'b10;  // Future
    localparam OP_KEYVAULT       = 2'b11;  // Future

    // SHA-256 specific addresses and commands - CORRECTED VALUES
    localparam SHA_ADDR_CTRL     = 8'h08;
    localparam SHA_ADDR_STATUS   = 8'h09;
    localparam SHA_ADDR_BLOCK0   = 8'h10;
    localparam SHA_ADDR_DIGEST0  = 8'h20;
    
    // CRITICAL FIX: Proper SHA-256 control values
    localparam SHA_CTRL_INIT_256 = 32'h00000005;  // INIT=1 + MODE=1 (bits 0,2)
    localparam SHA_CTRL_NEXT_256 = 32'h00000006;  // NEXT=1 + MODE=1 (bits 1,2)

    // Status bits (corrected bit positions)
    localparam SHA_STATUS_READY  = 0;
    localparam SHA_STATUS_VALID  = 1;

    // Registers
    reg [3:0]                state;
    reg [3:0]                next_state;
    reg [CMD_WIDTH-1:0]      operation_code;
    reg [15:0]               data_buffer [0:31];  // Buffer for incoming data
    reg [5:0]                buffer_index;
    reg [5:0]                data_length;
    reg [4:0]                sha_block_word;      // Current word in SHA block (0-15)
    reg [31:0]               temp_32bit_data;
    reg [1:0]                word_assembly_state; // For combining 16-bit to 32-bit
    reg                      busy_flag;
    reg [31:0]               sha_digest [0:7];    // Store SHA-256 result
    reg [3:0]                digest_word_index;
    reg [15:0]               response_buffer [0:15];
    reg [4:0]                response_index;
    reg [4:0]                response_length;
    reg [15:0]               wait_counter;        // Extended for longer SHA processing
    reg [31:0]               message_length_bits; // Message length in bits for SHA padding
    reg [2:0]                sha_read_wait;       // Wait cycles for SHA reads

    assign o_spi_busy = busy_flag;

    // Main state machine
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            state <= IDLE;
            operation_code <= 2'b00;
            buffer_index <= 6'b0;
            data_length <= 6'b0;
            sha_block_word <= 5'b0;
            temp_32bit_data <= 32'b0;
            word_assembly_state <= 2'b0;
            busy_flag <= 1'b0;
            digest_word_index <= 4'b0;
            response_index <= 5'b0;
            response_length <= 5'b0;
            wait_counter <= 16'b0;
            message_length_bits <= 32'b0;
            sha_read_wait <= 3'b0;
            o_status_reg <= 8'h00;
            o_operation_complete <= 1'b0;
            o_sha_cs <= 1'b0;
            o_sha_we <= 1'b0;
            o_sha_address <= 8'h00;
            o_sha_write_data <= 32'h00000000;
            o_spi_tx_data <= 16'h0000;
            o_spi_tx_valid <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (i_spi_rx_valid) begin
                    next_state = DECODE_CMD;
                end
            end
            
            DECODE_CMD: begin
                if (operation_code == OP_SHA256) begin
                    if (buffer_index >= data_length) begin
                        next_state = SHA_INIT;
                    end else begin
                        next_state = RECEIVE_DATA;
                    end
                end else begin
                    next_state = ERROR_STATE;
                end
            end
            
            RECEIVE_DATA: begin
                if (buffer_index >= data_length) begin
                    next_state = SHA_INIT;
                end
            end
            
            SHA_INIT: begin
                if (wait_counter >= 16'd10) begin
                    next_state = SHA_LOAD_BLOCK;
                end
            end
            
            SHA_LOAD_BLOCK: begin
                if (sha_block_word >= 5'd16 && word_assembly_state == 2'b00) begin
                    next_state = SHA_PROCESS;
                end
            end
            
            SHA_PROCESS: begin
                if (wait_counter >= 16'd10) begin
                    next_state = SHA_WAIT_READY;
                end
            end
            
            SHA_WAIT_READY: begin
                if (i_sha_read_data[SHA_STATUS_VALID] && wait_counter >= 16'd10) begin
                    next_state = SHA_READ_DIGEST;
                end else if (wait_counter >= 16'd10000) begin  // Much longer timeout
                    next_state = ERROR_STATE;
                end
            end
            
            SHA_READ_DIGEST: begin
                if (digest_word_index >= 4'd8 && sha_read_wait == 3'b000) begin
                    next_state = SEND_RESPONSE;
                end
            end
            
            SEND_RESPONSE: begin
                if (response_index >= response_length) begin
                    next_state = IDLE;
                end
            end
            
            ERROR_STATE: begin
                if (wait_counter >= 16'd100) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State machine operations - WITH CORRECTED SHA CONTROL VALUES
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                IDLE: begin
                    busy_flag <= 1'b0;
                    o_operation_complete <= 1'b0;
                    buffer_index <= 6'b0;
                    o_spi_tx_valid <= 1'b0;
                    o_sha_cs <= 1'b0;
                    o_sha_we <= 1'b0;
                    sha_block_word <= 5'b0;
                    digest_word_index <= 4'b0;
                    response_index <= 5'b0;
                    wait_counter <= 16'b0;
                    word_assembly_state <= 2'b0;
                    sha_read_wait <= 3'b0;
                    o_status_reg <= 8'h01; // Ready status
                    
                    if (i_spi_rx_valid) begin
                        // CORRECTED: Proper command parsing
                        operation_code <= i_spi_rx_data[15:14];  // Top 2 bits
                        data_length <= {2'b00, i_spi_rx_data[13:10]};  // Next 4 bits
                        data_buffer[1] <= i_spi_rx_data;
                        buffer_index <= 6'b10; // Start from index 2
                        busy_flag <= 1'b1;
                        o_status_reg <= 8'h02; // Processing status
                    end
                end
                
                DECODE_CMD: begin
                    if (operation_code == OP_SHA256) begin
                        if (data_length < 6'd2) begin
                            data_length <= 6'd2; // Minimum 2 words
                        end
                    end
                end
                
                RECEIVE_DATA: begin
                    if (i_spi_rx_valid && buffer_index < data_length) begin
                        data_buffer[buffer_index] <= i_spi_rx_data;
                        buffer_index <= buffer_index + 1;
                    end
                end
                
                SHA_INIT: begin
                    // CRITICAL FIX: Use corrected control value
                    if (wait_counter < 16'd5) begin
                        o_sha_cs <= 1'b1;
                        o_sha_we <= 1'b1;
                        o_sha_address <= SHA_ADDR_CTRL;
                        o_sha_write_data <= SHA_CTRL_INIT_256;  // FIXED: Set INIT + MODE bits
                        wait_counter <= wait_counter + 1;
                    end else if (wait_counter < 16'd10) begin
                        o_sha_we <= 1'b0;
                        wait_counter <= wait_counter + 1;
                    end else begin
                        o_sha_cs <= 1'b0;
                        wait_counter <= 16'b0;
                        sha_block_word <= 5'b0;
                        word_assembly_state <= 2'b0;
                        // Calculate message length: (data_length - 1) * 16 bits
                        message_length_bits <= (data_length - 1) * 16;
                    end
                end
                
                SHA_LOAD_BLOCK: begin
                    // Load SHA block with proper padding
                    o_sha_cs <= 1'b1;
                    
                    if (sha_block_word < 5'd14) begin
                        // Load actual message data
                        case (word_assembly_state)
                            2'b00: begin
                                if ((sha_block_word + 1) < data_length) begin
                                    temp_32bit_data <= {data_buffer[sha_block_word + 1], 16'h0000};
                                    word_assembly_state <= 2'b01;
                                end else begin
                                    // Padding: add 0x8000... for partial word
                                    temp_32bit_data <= {16'h8000, 16'h0000};
                                    word_assembly_state <= 2'b01;
                                end
                            end
                            
                            2'b01: begin
                                o_sha_we <= 1'b1;
                                o_sha_address <= SHA_ADDR_BLOCK0 + sha_block_word;
                                o_sha_write_data <= temp_32bit_data;
                                word_assembly_state <= 2'b10;
                            end
                            
                            2'b10: begin
                                o_sha_we <= 1'b0;
                                sha_block_word <= sha_block_word + 1;
                                word_assembly_state <= 2'b00;
                            end
                        endcase
                    end else if (sha_block_word == 5'd14) begin
                        // Length high word (always 0 for our messages)
                        if (word_assembly_state == 2'b00) begin
                            o_sha_we <= 1'b1;
                            o_sha_address <= SHA_ADDR_BLOCK0 + sha_block_word;
                            o_sha_write_data <= 32'h00000000;
                            word_assembly_state <= 2'b01;
                        end else begin
                            o_sha_we <= 1'b0;
                            sha_block_word <= sha_block_word + 1;
                            word_assembly_state <= 2'b00;
                        end
                    end else if (sha_block_word == 5'd15) begin
                        // Length low word
                        if (word_assembly_state == 2'b00) begin
                            o_sha_we <= 1'b1;
                            o_sha_address <= SHA_ADDR_BLOCK0 + sha_block_word;
                            o_sha_write_data <= message_length_bits;
                            word_assembly_state <= 2'b01;
                        end else begin
                            o_sha_we <= 1'b0;
                            sha_block_word <= sha_block_word + 1;
                            word_assembly_state <= 2'b00;
                        end
                    end
                end
                
                SHA_PROCESS: begin
                    // CRITICAL FIX: Use corrected control value
                    if (wait_counter < 16'd5) begin
                        o_sha_cs <= 1'b1;
                        o_sha_we <= 1'b1;
                        o_sha_address <= SHA_ADDR_CTRL;
                        o_sha_write_data <= SHA_CTRL_INIT_256;  // FIXED: Set INIT + MODE bits
                        wait_counter <= wait_counter + 1;
                    end else if (wait_counter < 16'd10) begin
                        o_sha_we <= 1'b0;
                        wait_counter <= wait_counter + 1;
                    end else begin
                        o_sha_cs <= 1'b0;
                        wait_counter <= 16'b0;
                    end
                end
                
                SHA_WAIT_READY: begin
                    // Poll status register with longer timeout
                    if (wait_counter[3:0] == 4'h0) begin  // Poll every 16 cycles
                        o_sha_cs <= 1'b1;
                        o_sha_we <= 1'b0;
                        o_sha_address <= SHA_ADDR_STATUS;
                    end else begin
                        o_sha_cs <= 1'b0;
                    end
                    wait_counter <= wait_counter + 1;
                end
                
                SHA_READ_DIGEST: begin
                    // Read digest with proper timing
                    if (digest_word_index < 4'd8) begin
                        case (sha_read_wait)
                            3'b000: begin
                                o_sha_cs <= 1'b1;
                                o_sha_we <= 1'b0;
                                o_sha_address <= SHA_ADDR_DIGEST0 + digest_word_index;
                                sha_read_wait <= 3'b001;
                            end
                            
                            3'b001, 3'b010: begin
                                sha_read_wait <= sha_read_wait + 1;
                            end
                            
                            3'b011: begin
                                sha_digest[digest_word_index] <= i_sha_read_data;
                                digest_word_index <= digest_word_index + 1;
                                sha_read_wait <= 3'b000;
                                o_sha_cs <= 1'b0;
                            end
                        endcase
                    end else begin
                        // Prepare response: 256-bit hash as 16x16-bit words
                        response_buffer[0] <= sha_digest[0][31:16];
                        response_buffer[1] <= sha_digest[0][15:0];
                        response_buffer[2] <= sha_digest[1][31:16];
                        response_buffer[3] <= sha_digest[1][15:0];
                        response_buffer[4] <= sha_digest[2][31:16];
                        response_buffer[5] <= sha_digest[2][15:0];
                        response_buffer[6] <= sha_digest[3][31:16];
                        response_buffer[7] <= sha_digest[3][15:0];
                        response_buffer[8] <= sha_digest[4][31:16];
                        response_buffer[9] <= sha_digest[4][15:0];
                        response_buffer[10] <= sha_digest[5][31:16];
                        response_buffer[11] <= sha_digest[5][15:0];
                        response_buffer[12] <= sha_digest[6][31:16];
                        response_buffer[13] <= sha_digest[6][15:0];
                        response_buffer[14] <= sha_digest[7][31:16];
                        response_buffer[15] <= sha_digest[7][15:0];
                        response_length <= 5'd16;
                        response_index <= 5'b0;
                        sha_read_wait <= 3'b000;
                    end
                end
                
                SEND_RESPONSE: begin
                    // Send hash back via SPI
                    if (i_spi_tx_ready && response_index < response_length) begin
                        o_spi_tx_data <= response_buffer[response_index];
                        o_spi_tx_valid <= 1'b1;
                        response_index <= response_index + 1;
                    end else begin
                        o_spi_tx_valid <= 1'b0;
                    end
                    
                    if (response_index >= response_length) begin
                        o_operation_complete <= 1'b1;
                        o_status_reg <= 8'h03; // Complete status
                    end
                end
                
                ERROR_STATE: begin
                    o_status_reg <= 8'hFF; // Error status
                    o_sha_cs <= 1'b0;
                    o_sha_we <= 1'b0;
                    o_spi_tx_valid <= 1'b0;
                    wait_counter <= wait_counter + 1;
                end
            endcase
        end
    end

endmodule
