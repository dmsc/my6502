
`include "rtl/cpu.v"
`include "rtl/ALU.v"
`include "rtl/timer.v"
`include "rtl/uart.v"
`include "rtl/minirom.v"

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
     # 12000 $finish;
  end

  system sys1(
      .rst(rst),
      .clk(clk),
      .uart_tx(tx),
      .uart_rx(rx)
  );


endmodule
