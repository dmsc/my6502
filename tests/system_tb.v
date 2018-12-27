`timescale 1us/1ns

module test;

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  reg rst;
  wire rx, tx;

  initial begin
     string vcd_file;
     if (!$value$plusargs("vcd=%s", vcd_file)) begin
         $display("Specify output VCD file with +vcd=<file>.");
         $finish_and_return(1);
     end
     $dumpfile(vcd_file);
     $dumpvars(0,test);
     rst = 0;
     # 7
     rst = 1;
     # 9
     rst = 0;
     # 500000 $finish;
  end

  system #(
      .CLK_HZ(9*115200)
  ) sys1 (
      .rst(rst),
      .clk25(clk),
      .uart_tx(tx),
      .uart_rx(rx)
  );


endmodule
