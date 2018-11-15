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
    reg active;         // Timer active
    reg shot;           // Timer reached count (reset on timer write)
    wire chip_read = cs & !we;
    wire chip_write = cs & we;
    wire nonzero = |counter;

/*
    // Use non-clocked logic for DBR
    assign dbr = (!chip_read) ? 8'bx :
                 ( (addr == 0) ? counter[7:0] :
                 ( (addr == 1) ? counter[15:0] :
                   {shot,6'bx,active}  ) );
*/

    // main process
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            counter <= 0;
            shot <= 0;
            active <= 0;
        end
        else
        begin
            // Process writes to registers
            if (chip_write)
            begin
                if (addr == 0)
                    counter = counter + dbw;
                else if (addr == 1)
                    counter[15:8] = counter[15:8] + dbw;
                else if (addr == 2)
                begin
                    shot = dbw[7];
                    active = dbw[0];
                end
            end
            else if (chip_read)
            begin
                if (addr == 0)
                    dbr = counter[7:0];
                else if (addr == 1)
                    dbr = counter[15:8];
                else
                begin
                    dbr = {shot,6'b0,active};
                end
            end

            // Process timer
            if (active)
            begin
                counter <= counter - 1;
                if (!nonzero)
                    shot <= 1;
            end
        end
    end

endmodule

