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

// PS/2 keyboard interface

// Simple de-bouncer, used in clock and data lines
// Counts up to 31 before registering a line change
module ps2_debouncer (
    input  pin,
    output out,
    input  clk
    );

    reg fpin      = 0;
    reg [4:0] cnt = 0;
    reg value     = 0;

    assign out = value;

    always @(posedge clk)
    begin
        fpin <= pin; // Synchronize
        if (fpin == value)
            cnt <= 0;
        else
        begin
            if (cnt == 5'b11111)
            begin
                value <= fpin;
                cnt <= 0;
            end
            else
                cnt <= cnt + 1;
        end
    end
endmodule

module ps2_kbd (
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  addr,        // Address bus - 2 registers
    input  we,          // write
    input  rst,         // reset
    input  clk,         // Clock
    inout  ps2_data,    // External pin PS2_DATA
    inout  ps2_clock    // External pin PS2_CLOCK
    );

    wire clock_raw, clock_in, data_raw, data_in, clock_out;

    ps2_debouncer db_clock ( .pin(clock_raw | rx_hold), .out(clock_in), .clk(clk) );
    ps2_debouncer db_data  ( .pin(data_raw), .out(data_in), .clk(clk) );


    reg rx_hold;
    reg [10:0] rx_shift; // Includes Start, Parity and Stop.
    reg state;           // Clock state
    reg code_rel;        // Processed a release code   (F0)
    reg code_ext;        // Processed an extended code (E0)

    assign clock_out = !rx_hold;

    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            rx_shift <= {1, 10'b0};
            rx_hold  <= 0;
            state    <= 0;
            code_rel <= 0;
            code_ext <= 0;
        end
        else
        begin
            if (rx_hold)
            begin
                // We don't process signals in rx_hold state
                if( we )
                begin
                    rx_hold  <= 0;
                    rx_shift <= {1, 10'b0};
                    code_rel <= 0;
                    code_ext <= 0;
                end
            end
            else
            begin
                // Next state depending on current state:
                if( clock_in == state )
                begin
                    if( state == 0 )
                        state <= 1;
                    else
                    begin
                        // On EVEN states we shift in the data value
                        state <= 0;
                        if( rx_shift[0] )
                        begin
                            // Last transition, we hold received byte and
                            // go to initial state.
                            if( rx_shift[9:2] == 8'hF0 ||
                                rx_shift[9:2] == 8'hE0 ||
                                rx_shift[9:2] == 8'hE1 )
                            begin
                                // This is a "release" code or an "extended"
                                // code, skip and process next code
                                if (rx_shift[6] == 1)
                                    code_rel <= 1;
                                else
                                    code_ext <= 1;
                                rx_hold  <= 0;
                                rx_shift <= {1, 10'b0};
                            end
                            else
                            begin
                                rx_hold <= 1;
                            end
                        end
                        else
                            rx_shift <= {data_in, rx_shift[10:1] };
                    end
                end
            end

            // Process reads from registers
            if (!we)
            begin
                case(addr)
                                 // VALID  / RELEASE / PARITY      / EXTENDED/  0 0 0 0
                    2'b00: dbr <= { rx_hold, code_rel, rx_shift[10], code_ext, 4'b0 };
                    2'b01: dbr <= { rx_shift[9] | code_ext, rx_shift[8:2] };
                endcase
            end
        end
    end


    // PS/2 data input
    (* PULLUP_RESISTOR = "3P3K" *)
    SB_IO #(
        .PIN_TYPE(6'b000001),   // Simple input pin (D_IN_0), no output
        .PULLUP(1'b1)
    ) io_ps2_data (
        .PACKAGE_PIN(ps2_data),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b0),
        .D_IN_0(data_raw),
        .D_IN_1()
    );

    // PS/2 clock input/output
    (* PULLUP_RESISTOR = "3P3K" *)
    SB_IO #(
        .PIN_TYPE(6'b101001),   // Simple input pin (D_IN_0) and open drain output
        .PULLUP(1'b1)
    ) io_ps2_clock (
        .PACKAGE_PIN(ps2_clock),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(!clock_out),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b0),
        .D_IN_0(clock_raw),
        .D_IN_1()
    );

endmodule

