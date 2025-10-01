//==================================================================
//SHA-256 Test - Testing "cd" 
//==================================================================

`timescale 1ns / 1ps

module tb_sha256();

    parameter CLK_PERIOD = 10;
    
    reg          clk;
    reg          reset_n;
    reg          cs;
    reg          we;
    reg  [7:0]   address;
    reg  [31:0]  write_data;
    wire [31:0]  read_data;
    wire         error;
    
    integer      i;
    reg  [31:0]  status_word;
    reg  [31:0]  digest [0:7];
    
    // SHA-256 core instance
    sha256 dut (
        .clk        (clk),
        .reset_n    (reset_n),
        .cs         (cs),
        .we         (we),
        .address    (address),
        .write_data (write_data),
        .read_data  (read_data),
        .error      (error)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test
    initial begin
        $display("Simple SHA-256 Test for 'cd' Starting...");  
        
        // Initialize
        reset_n = 0;
        cs = 0;
        we = 0;
        address = 8'h00;
        write_data = 32'h00000000;
        
        // Reset
        #100;
        reset_n = 1;
        #50;
        
        // Write control
        cs = 1;
        we = 1;
        address = 8'h08;
        write_data = 32'h00000005;
        #20;
        cs = 0;
        we = 0;
        #50;
        
        // Write first word (cd + padding)  
        cs = 1;
        we = 1; 
        address = 8'h10;
        write_data = 32'h63648000;  // ← "cd" 
        #20;
        cs = 0;
        we = 0;
        #20;
        
        // Write zeros for padding (same as before)
        for (i = 8'h11; i < 8'h1E; i = i + 1) begin
            cs = 1;
            we = 1;
            address = i;
            write_data = 32'h00000000;
            #20;
            cs = 0;
            we = 0;
            #20;
        end
        
        // Write length (16 bits for 2-character message)
        cs = 1;
        we = 1;
        address = 8'h1E;
        write_data = 32'h00000000;
        #20;
        cs = 0;
        we = 0;
        #20;
        
        cs = 1;
        we = 1;
        address = 8'h1F;
        write_data = 32'h00000010;  // 16 bits
        #20;
        cs = 0;
        we = 0;
        #50;
        
        // Start processing 
        cs = 1;
        we = 1;
        address = 8'h08;
        write_data = 32'h00000005;
        #20;
        cs = 0;
        we = 0;
        #100;
        
        // Wait for completion 
        status_word = 0;
        while (!status_word[1]) begin
            cs = 1;
            we = 0;
            address = 8'h09;
            #30;
            status_word = read_data;
            cs = 0;
            #100;
        end
        
        $display("Processing completed! Status: %h", status_word);
        
        // Read digest 
        for (i = 0; i < 8; i = i + 1) begin
            cs = 1;
            we = 0;
            address = 8'h20 + i;
            #30;
            digest[i] = read_data;
            cs = 0;
            #20;
        end
        
        // Display results
        $display("Digest Results for 'cd':");  
        for (i = 0; i < 8; i = i + 1) begin
            $display("  Word %0d: %h", i, digest[i]);
        end
        
        $display("Complete hash: %h%h%h%h%h%h%h%h", 
                 digest[0], digest[1], digest[2], digest[3],
                 digest[4], digest[5], digest[6], digest[7]);
        
        $display("Test for 'cd' completed!");  
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("Test timeout");
        $finish;
    end

endmodule
