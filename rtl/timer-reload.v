// Simple 16 bit timer

module timer(
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [1:0] addr,  // Address bus - two bits
    input  cs,          // chip select
    input  we,          // write/read
    input  rst,         // reset
    input  clk          // Clock
    );


    reg [15:0] counter; // Timer count
    reg [15:0] reload;  // Timer reload
    reg active;         // Timer active
    reg reactive;       // Timer reactivation
    reg shot;           // Timer reached count (reset on timer write)
    wire chip_read = cs & !we;
    wire chip_write = cs & we;
    wire nonzero = |counter;


    // main process
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            counter <= 0;
            shot <= 0;
            active <= 0;
            reactive <= 0;
            dbr <= 0;
        end
        else
        begin
            // Process writes to registers
            dbr = 0;
            if (chip_write)
            begin
                if (addr == 0)
                    reload[7:0] = dbw;
                else if (addr == 1)
                    reload[15:8] = dbw;
                else if (addr == 2)
                begin
                    shot = dbw[7];
                    reactive = dbw[1];
                    active = dbw[0];
                end
            end
            else if (chip_read)
            begin
                if (addr == 0)
                    dbr = counter[7:0];
                else if (addr == 1)
                    dbr = counter[15:8];
                else if (addr == 2)
                begin
                    dbr[7] = shot;
                end
            end

            // Process timer
            if (active)
            begin
                if (nonzero)
                    counter <= counter - 1;
                else if (reactive)
                begin
                    counter <= reload;
                    shot <= 0;
                end
                else
                    active <= 0;
            end
        end
    end

endmodule

