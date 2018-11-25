`timescale 1us/1ns

module TB_SB_HFOSC(
    output CLKHF,
    input CLKHFEN,
    input CLKHFPU
);
    parameter CLKHF_DIV = 2'b0;

    reg clk;
    always #0.083 clk = (clk === 1'b0);
    assign CLKHF = clk & CLKHFEN;

endmodule

// Expected output from TX:
// ------------------------
// S11010100T   $2B     +
// S11101010T   $57     W       (400ms)
// S10100110T   $65     e
// S00110110T   $6C     l
// S11000110T   $63     c
// S11110110T   $6F     o

module test;

    wire tx,rx, clk_1, clk_2;

    initial begin
        string vcd_file;
        if (!$value$plusargs("vcd=%s", vcd_file)) begin
            $display("Specify output VCD file with +vcd=<file>.");
            $finish_and_return(1);
        end
        $dumpfile(vcd_file);
        $dumpvars(0,test);
        # 500000 $finish; // Simulate 500ms
    end


    upduino up(.uart_tx(tx), .uart_rx(rx), .clk_1(clk_1), .clk_2(clk_2) );

endmodule
