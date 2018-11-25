// 64 kbytes of ram

module ram(
    output reg [7:0] dbr, // Data bus READ
    input  [7:0] dbw,   // Data bus READ
    input  [15:0] addr, // Address bus - eight bits
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

    always @(*)
    begin
        if (ramsel == 2'b00)
            dbr <= dataout0[7:0];
        else if (ramsel == 2'b01)
            dbr <= dataout0[15:8];
        else if (ramsel == 2'b10)
            dbr <= dataout1[7:0];
        else // if (ramsel == 2'b11)
            dbr <= dataout1[15:8];
    end

endmodule

