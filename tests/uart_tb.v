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

// Test module for uart

  `define check(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED t=%t: signal != value  [%h]", $time, signal); \
            $finish; \
        end

module test;

  localparam FREQ = 14;

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  reg cs, we, addr, rst, rx;
  reg [7:0] dbw;
  wire [7:0] dbr;


  initial begin
     string vcd_file;
     if (!$value$plusargs("vcd=%s", vcd_file)) begin
         $display("Specify output VCD file with +vcd=<file>.");
         $finish_and_return(1);
     end
     $dumpfile(vcd_file);
     $dumpvars(0,test);
     rst = 0;
     cs = 0;
     we = 0;
     dbw = 8'b0;
     addr = 0;
     # 7
     rst = 1;
     # 9
     rst = 0;
     # 16
     dbw = 8'b01111011;
     cs  = 1;
     we  = 1;
     addr = 0;
     # 2
     `check(dbr, 0);
     cs = 0;
     we = 0;
     # 4
     dbw = 8'd62;
     cs  = 1;
     we  = 1;
     addr = 0;
     # 2
     cs = 0;
     we = 0;
     # (100 + (FREQ-4)*16)
     dbw = 8'd255;
     cs  = 1;
     we  = 1;
     addr = 0;
     # 2
     cs = 0;
     we = 0;
     # 20
     addr = 1;
     cs = 1;
     # 2
     `check(dbr[7], 0);
     cs = 0;
     # 20
     cs = 1;
     # 2
     `check(dbr[7], 0);
     cs = 0;
     # (FREQ * 30 - 100)
     cs = 1;
     # 2
     `check(dbr[7], 0);
     cs = 0;
     # (140 + (FREQ-4)*30)
     dbw = 8'd0;
     cs  = 1;
     we  = 1;
     addr = 0;
     # 2
     cs = 0;
     we = 0;
     # 8000 $finish;
  end

  initial begin
      rx = 1;
      #123
                 rx = 0; // S
      # (FREQ*2) rx = 1; // 7
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 1;
      # (FREQ*2) rx = 0; // 4
      # (FREQ*2) rx = 1;
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 1; // 1
      # (FREQ*2) rx = 0; // 0
      # (FREQ*2) rx = 1; // T

      # (FREQ*2+3)
 //     #221
                 rx = 0; // S
      # (FREQ*2) rx = 1; // 7
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 0; // 4
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 0;
      # (FREQ*2) rx = 0; // 1
      # (FREQ*2) rx = 1; // 0
      # (FREQ*2) rx = 1; // T
  end

  wire tx;
  uart #(
      .CLK_HZ(115200 * FREQ)
  ) uart1 (
      .dbr(dbr),
      .dbw(dbw),
      .addr(addr),
      .we(we & cs),
      .rst(rst),
      .clk(clk),
      .tx(tx),
      .rx(rx)
  );


  initial
     $monitor("At time %t, tx: %h, dbr: %h", $time, tx, dbr);

endmodule // test
