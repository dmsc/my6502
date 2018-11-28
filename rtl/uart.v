// A simple UART for an 8 bit bus

// Baud rate generator
module baud_gen(
    output sample,      // Active for one clock cycle and then inactive for divisor cycles
    input  active,      // Only count if active == 1
    input  clk,         // Clock input
    input  rst          // Master reset
    );

    parameter DIVISOR = 5;      // The divisor

    localparam DIV_W = $clog2(DIVISOR+1);       // Counter width

    reg [DIV_W-1:0] count;

    assign sample = (count == DIVISOR);
    always @(posedge clk or posedge rst)
    begin
        if (rst)
            count <= 0;
        else
            count <= (!active | sample) ? 0 : (count+1);
    end

endmodule

module uart(
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [0:0] addr,  // Address bus - only one bit
    input  we,          // write/read
    input  rst,         // reset
    input  clk,         // Clock
    output reg tx,      // TX data bit
    input  rx           // RX data bit
    );

    parameter CLK_HZ = 115200*5; // Master clock: 25MHz
    parameter BAUD = 115200;

    wire chip_write = we;

    // Internal TX registers
    localparam TX_DIVISOR = CLK_HZ / BAUD - 1;  // Our divisor
    reg [8:0] tx_next;  // Next byte to transmit plus stop bit
    reg [7:0] tx_crnt;  // Current byte being transmitted - copied from tx_next on idle
    reg [3:0] tx_state; // TX State: 0 == idle, 10 to 1 = transmitting
    wire tx_active = |tx_state;
    wire tx_bit;

    // Internal RX registers
    localparam RX_DIVISOR = CLK_HZ / (2 * BAUD) - 1;    // Our divisor
    reg [7:0] rx_buf;   // Received byte buffer.
    reg [7:0] rx_shift; // Byte being shifted into receiver.
    reg [4:0] rx_state; // RX State: 0 == idle, 10 to 1 = receiving
    reg rx_ok;
    reg rx_latch;
    wire rx_active = |rx_state;
    wire rx_bit;

    // TX baud-rate generator
    baud_gen #(
        .DIVISOR(TX_DIVISOR)
    ) baud_tx (
        .sample( tx_bit ),
        .active( tx_active ),
        .clk( clk ),
        .rst( rst )
    );

    // RX baud-rate generator
    baud_gen #(
        .DIVISOR(RX_DIVISOR)
    ) baud_rx (
        .sample( rx_bit ),
        .active( rx_active ),
        .clk( clk ),
        .rst( rst )
    );

    // UART state machine
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            tx_state <= 0;
            tx <= 1;
            tx_crnt <= 0;
            tx_next <= 9'b000000000;
            dbr <= 0;
            rx_state <= 0;
            rx_shift <= 0;
            rx_buf <= 0;
            rx_ok <= 0;
            rx_latch <= 1;
        end
        else
        begin
            // Process writes to registers
            if (chip_write)
            begin
                if (addr[0] == 1'b0)
                begin
                    // TODO: signal overrun (tx_next[8] == 1)
                    tx_next <= { 1'b1, dbw };
                end
                else
                begin
                    rx_ok <= 0;
                end
            end
            else // chip_read
            begin
                if (addr == 1'b1)
                    dbr <= { tx_next[8], rx_ok, 6'b0 };
                else
                    dbr <= rx_buf;
            end

            // Main TX processing
            if (tx_active)
            begin
                if (tx_bit)
                begin
                    { tx_crnt, tx } <= { 1'b1, tx_crnt }; // Shift one bit to output
                    tx_state <= tx_state - 1;
                end
            end
            else if (tx_next[8] == 1)
            begin
                { tx_crnt, tx } <= { tx_next[7:0] , 1'b0 };// Shift start bit and next byte
                tx_next[8] <= 0;
                tx_state <= 10;
            end

            // Latches RX signal, prevents glitches
            rx_latch <= rx;

            // Main RX processing
            if (!rx_active)
            begin
                if (!rx_latch)
                begin
                    rx_shift <= 0;
                    rx_state <= 19;
                end
            end
            else if (rx_bit)
            begin
                if (rx_state[0])
                begin
                    // Shifts new bit
                    rx_shift <= { rx_latch, rx_shift[7:1] };
                    // Tests if we are at stop bit
                    if ( rx_state[4:1] == 0 )
                    begin
                        rx_buf <= rx_shift;
                        rx_ok  <= 1;
                    end
                end

                rx_state <= rx_state + 31;

            end
        end
    end

endmodule
