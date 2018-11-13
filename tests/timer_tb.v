// Test module for uart

`define check(signal, value) \
    if (signal !== value) begin \
        $display("ASSERTION FAILED t=%t: signal != value  [%h]", $time, signal); \
        $finish; \
    end

`define write(value, xaddr) \
    @(negedge clk); \
    dbw = value; \
    addr = xaddr; \
    we  = 1; \
    cs  = 1; \
    # 2 \
    cs = 0; \
    we = 0; \
    dbw = 0;

`define read_chk(value, xaddr) \
    @(negedge clk); \
    addr = xaddr; \
    we  = 0; \
    cs  = 1; \
    # 2 \
    `check(dbr, value); \
    cs = 0; \
    we = 0; \

module test;

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  reg cs, we, rst;
  reg [1:0] addr;
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
     # 8
 //    `check(dbr, 0);
     # 16
     `write(   0, 2 );  // disable timer
     `write( 232, 0 );  // Set limit == 1000
     `write(   3, 1 );
     `write(   1, 2 );  // enable timer
     # 1400
     `read_chk(8'b0xxxxxx1, 2);
     # 594
     `read_chk(8'b0xxxxxx1, 2);
     # 2
     `read_chk(8'b1xxxxxx1, 2);
     # 78
     `write( 100, 0 );  // Set limit == 100
     `write(   0, 1 );
     `write(   1, 2 );
     # 110
     `read_chk(8'b0xxxxxx1, 2);
     # 2
     `read_chk(8'b1xxxxxx1, 2);
     # 400 $finish;
  end

  timer timer1 (
      .dbr(dbr),
      .dbw(dbw),
      .addr(addr),
      .cs(cs),
      .we(we),
      .rst(rst),
      .clk(clk)
  );

  initial
     $monitor("At time %5d, [%h %h %b %b] A:%b S:%b", $time, dbr, dbw, cs, we, timer1.active, timer1.shot);

endmodule // test
