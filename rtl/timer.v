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

// Simple 16 bit timer

module timer(
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [1:0] addr,  // Address bus - two bits
    input  we,          // write/read
    input  rst,         // reset
    input  clk          // Clock
    );


    reg [15:0] counter; // Timer count
    reg active;         // Timer active
    reg shot;           // Timer reached count (reset on timer write)
    wire chip_read = !we;
    wire chip_write = we;

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
            // Process timer
            if (active)
            begin
                counter <= counter - 1;
                if (counter == 0)
                    shot <= 1;
            end

            // Process writes to registers
            if (chip_write)
            begin
                // NOTE: writing to the counter here will inhibit the
                //       decrementing above, so we loose two cycles for
                //       each full write.
                if (addr == 0)
                    counter <= counter + dbw;
                else if (addr == 1)
                    counter <= counter + (dbw * 256); // NOTE: "<<8" uses a lot more PLBs???
                else if (addr == 2)
                begin
                    shot <= dbw[7];
                    active <= dbw[0];
                    if (dbw[0] == 0) // Wen timer de-activates, the count is reset to 0
                        counter <= 0;
                end
            end
            else if (chip_read)
            begin
                if (addr == 0)
                    dbr <= counter[7:0];
                else if (addr == 1)
                    dbr <= counter[15:8];
                else
                begin
                    dbr <= {shot,6'b0,active};
                end
            end
        end
    end

endmodule

