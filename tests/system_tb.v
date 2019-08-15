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

`timescale 1us/1ns

module test;

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  reg rst, miso_reg;
  wire rx, tx, mosi, miso, ss0, sclk;

  initial begin
     string vcd_file;
     if (!$value$plusargs("vcd=%s", vcd_file)) begin
         $display("Specify output VCD file with +vcd=<file>.");
         $finish_and_return(1);
     end
     $dumpfile(vcd_file);
     $dumpvars(0,test);
     $display("Loading RAM");
     $readmemh("tests/ram0.mem", sys1.ram1.ram0.mem);
     $readmemh("tests/ram1.mem", sys1.ram1.ram1.mem);
     $readmemh("tests/vram0.mem", sys1.vram1.ram0.mem);
     $readmemh("tests/vram1.mem", sys1.vram1.ram1.mem);
     $display("Starting simulation");
     rst = 0;
     # 7
     rst = 1;
     # 9
     rst = 0;
     # 500000 $finish;
  end

  initial begin
     miso_reg = 1;
     # 22889
     miso_reg = 0;
     # 48
     miso_reg = 1;
     # 8
     miso_reg = 0;
     # 48
     miso_reg = 1;
     # 20
     miso_reg = 0;
     forever miso_reg = #76 !miso_reg;
  end
  assign miso = (ss0 == 0) ? miso_reg : 1'bz;

  system #(
      .CLK_HZ(9*115200)
  ) sys1 (
      .rst(rst),
      .clk25(clk),
      .uart_tx(tx),
      .uart_rx(rx),
      .spi0_miso(miso),
      .spi0_mosi(mosi),
      .spi0_cs0(ss0),
      .spi0_sclk(sclk)
  );


endmodule
