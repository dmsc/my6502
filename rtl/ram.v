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

// 64 kbytes of 8bit ram

module ram(
    output reg [7:0] dbr, // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [15:0] addr, // Address bus - sixteen bits
    input  we,          // Write/Read
    input  clk          // Clock
    );


    wire [15:0] datain = { dbw, dbw };
    wire [15:0] dataout0;
    wire [15:0] dataout1;

    // Select which half to write:
    wire wselL = ~addr[0];
    wire wselH =  addr[0];

    // Select which RAM to write
    wire we0 = we & ~addr[1];
    wire we1 = we &  addr[1];

    // two 32KB ram blocks:
    SB_SPRAM256KA ram0 (
        .ADDRESS(addr[15:2]),
        .DATAIN(datain),
        .MASKWREN({ wselH, wselH, wselL, wselL}),
        .WREN(we0),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(dataout0)
    );

    SB_SPRAM256KA ram1 (
        .ADDRESS(addr[15:2]),
        .DATAIN(datain),
        .MASKWREN({wselH, wselH, wselL, wselL}),
        .WREN(we1),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(dataout1)
    );

    reg [1:0] ramsel = 2'b0;
    always @(posedge clk)
    begin
        ramsel <= addr[1:0];
    end

    reg [15:0] data16;
    always @(*)
    begin
        if (ramsel[1] == 0)
            data16 <= dataout0;
        else
            data16 <= dataout1;
    end

    always @(*)
    begin
        if (ramsel[0] == 0)
            dbr <= data16[7:0];
        else
            dbr <= data16[15:8];
    end

endmodule

