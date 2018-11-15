// 256 bytes of "bootstrap" rom

module minirom(
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] addr,  // Address bus - eight bits
    input  cs,          // chip select
    input  clk          // Clock
    );


    reg [7:0] rom_data[0:255];

    initial
        $readmemh("build/minirom.hex", rom_data, 0, 255);

    always @(posedge clk)
        if (cs)
            dbr <= rom_data[addr];
        else
            dbr <= 8'bx;

endmodule

