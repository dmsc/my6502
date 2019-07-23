/*
 * Simple 6502 computer for ice40up5k FPGA.
 *
 * (C) Daniel Serpell, <daniel.serpell@gmail.com>
 *
 * Feel free to use this code in any project (commercial or not), as long as you
 * keep this message, and the copyright notice. This code is provided "as is",
 * without any warranties of any kind.
 *
 */

// Post synthesis test

`timescale 1ns/1ps

// Simulate the ice40 PLL
module TB_SB_PLL40_CORE (
        input   REFERENCECLK,
        output  PLLOUTCORE,
        output  PLLOUTGLOBAL,
        input   EXTFEEDBACK,
        input   [7:0] DYNAMICDELAY,
        output  LOCK,
        input   BYPASS,
        input   RESETB,
        input   LATCHINPUTVALUE,
        output  SDO,
        input   SDI,
        input   SCLK
);
        parameter FEEDBACK_PATH = "SIMPLE";
        parameter DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
        parameter DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
        parameter SHIFTREG_DIV_MODE = 1'b0;
        parameter FDA_FEEDBACK = 4'b0000;
        parameter FDA_RELATIVE = 4'b0000;
        parameter PLLOUT_SELECT = "GENCLK";
        parameter DIVR = 4'b0000;
        parameter DIVF = 7'b0000000;
        parameter DIVQ = 3'b000;
        parameter FILTER_RANGE = 3'b000;
        parameter ENABLE_ICEGATE = 1'b0;
        parameter TEST_MODE = 1'b0;
        parameter EXTERNAL_DIVIDE_FACTOR = 1;

        reg [3:0] clk = 0;
        reg lock = 0;
        always @(posedge REFERENCECLK)
        begin
            clk <= clk + 1;
            if( clk == 4'b1111 )
                lock <= 1;
        end
        // Simply pass clock from input to output
        assign PLLOUTCORE = REFERENCECLK;
        assign LOCK = lock;
endmodule

// Expected output from TX:
// ------------------------
// S11000100T   $23     #
// S10110000T   $0D     CR      (400ms)
// S01010000T   $0A     LF
// S00000110T   $60     `

module test;

    wire tx,rx;
    reg clk_1 = 0;
    // Simulate clock at 25.175MHz
    always #19.861 clk_1 = !clk_1;

    initial begin
        string vcd_file;
        if (!$value$plusargs("vcd=%s", vcd_file)) begin
            $display("Specify output VCD file with +vcd=<file>.");
            $finish_and_return(1);
        end
        $dumpfile(vcd_file);
        $dumpvars(0,test);
        $timeformat(-3,2," ms",4);
        # 17ms $finish; // Simulate slightly more than one frame
    end

    always #250us begin
        $display("Simulated %t", $time);
    end

    upduino up(.uart_tx(tx), .uart_rx(rx), .iclk(clk_1) );

endmodule
