

module TB_SB_HFOSC(
    output CLKHF,
    input CLKHFEN,
    input CLKHFPU
);

   reg clk;
   always #1 clk = (clk === 1'b0);
   assign CLKHF = clk & CLKHFEN;

endmodule

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
        # 30000 $finish; // Simulate half a second!
    end


    upduino up(.uart_tx(tx), .uart_rx(rx), .clk_1(clk_1), .clk_2(clk_2) );

endmodule
